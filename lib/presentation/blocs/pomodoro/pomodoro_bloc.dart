import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/pocketbase_sync_service.dart';
import '../../../core/services/pomodoro_alerts.dart';
import '../../../core/services/pomodoro_engine.dart';
import '../../../core/services/pomodoro_stats.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../data/models/pomodoro_session.dart';
import '../../../data/repositories/pomodoro_repository.dart';
import '../../../data/repositories/running_timer_repository.dart';
import 'pomodoro_event.dart';
import 'pomodoro_state.dart';

class PomodoroBloc extends Bloc<PomodoroEvent, PomodoroState> {
  final PomodoroRepository _repository;
  final RunningTimerRepository _runningTimerRepository;
  final PocketBaseSyncService? _syncService;
  final PomodoroAlerts? _alerts;
  final DateTime Function() _clock;
  final String _deviceLabel;
  final _uuid = const Uuid();
  Timer? _ticker;
  StreamSubscription<SyncCollection>? _syncSubscription;
  StreamSubscription<void>? _alertSubscription;
  String? _warnedPhase;
  String? _scheduledFor;
  bool _permitted = true;

  /// Alerts only for what happened just now, not for phases replayed after hours offline.
  static const _fresh = Duration(seconds: 30);

  PomodoroBloc({
    required PomodoroRepository repository,
    required RunningTimerRepository runningTimerRepository,
    PocketBaseSyncService? syncService,
    PomodoroAlerts? alerts,
    DateTime Function()? clock,
    String? deviceLabel,
    Duration? tickInterval = const Duration(seconds: 1),
  }) : _repository = repository,
       _runningTimerRepository = runningTimerRepository,
       _syncService = syncService,
       _alerts = alerts,
       _clock = clock ?? DateTime.now,
       _deviceLabel = deviceLabel ?? PlatformUtils.deviceLabel,
       super(PomodoroState(settings: repository.getSettings(), now: (clock ?? DateTime.now)())) {
    on<LoadPomodoro>(_onLoad);
    on<StartPomodoro>(_onStart);
    on<PausePomodoro>(_onPause);
    on<ResumePomodoro>(_onResume);
    on<SkipPomodoroPhase>(_onSkip);
    on<StartPendingPomodoroPhase>(_onStartPendingPhase);
    on<StopPomodoro>(_onStop);
    on<TickPomodoro>(_onTick);
    on<UpdatePomodoroSettings>(_onUpdateSettings);
    on<TogglePomodoroVisibility>(_onToggleVisibility);
    on<TogglePomodoroDeviceSounds>(_onToggleDeviceSounds);
    on<TogglePomodoroDeviceNotifications>(_onToggleDeviceNotifications);
    on<RequestPomodoroPermission>(_onRequestPermission);
    on<PreviewPomodoroSound>(_onPreviewSound);
    on<DeletePomodoroRecord>(_onDeleteRecord);
    on<RestorePomodoroRecord>(_onRestoreRecord);
    on<TogglePomodoroMobileTab>(_onToggleMobileTab);

    if (tickInterval != null) {
      _ticker = Timer.periodic(tickInterval, (_) {
        if (state.isActive) add(const TickPomodoro());
      });
    }
    _syncSubscription = _syncService?.onCollectionChanged.listen((collection) {
      if (collection == SyncCollection.pomodoroState || collection == SyncCollection.pomodoroSettings || collection == SyncCollection.pomodoroSessions) {
        add(const LoadPomodoro());
      }
    });
    _alertSubscription = _alerts?.startPendingRequests.listen((_) => add(const StartPendingPomodoroPhase()));
  }

  Future<void> _onLoad(LoadPomodoro event, Emitter<PomodoroState> emit) async {
    await _alerts?.init();
    await _checkPermission();
    await _refresh(emit);
  }

  Future<void> _onTick(TickPomodoro event, Emitter<PomodoroState> emit) async {
    await _refresh(emit);
    final s = state.session;
    if (s != null && s.isRunning && s.phase == PomodoroPhase.work && state.settings.ticking) _fire(() => _alerts!.tick());
  }

  Future<void> _onStart(StartPomodoro event, Emitter<PomodoroState> emit) async {
    try {
      await _syncService?.pullPomodoroState();
      final current = await _advanced();
      if (current != null) {
        if (!event.replaceExisting) {
          emit(_buildState(current, startConflict: current));
          return;
        }
        await _endSession(current, PomodoroEndReason.manual);
      }
      final session = PomodoroEngine.start(
        id: _uuid.v4(),
        settings: _repository.getSettings(),
        now: _clock(),
        startDevice: _deviceLabel,
        startedWithTimer: event.timerStarted || _runningTimerRepository.hasRunningTimers,
      );
      await _saveSession(session);
      _fire(() => _alerts!.workStarted());
      if (event.notifyIfNoTimer && !event.timerStarted) _warnIfNoTimer();
      if (!_permitted) {
        await _alerts?.requestPermission();
        await _checkPermission();
      }
      await _refresh(emit);
    } catch (e) {
      _emitError(emit, e);
    }
  }

  Future<void> _onPause(PausePomodoro event, Emitter<PomodoroState> emit) async {
    await _update(emit, (s) => PomodoroEngine.pause(s, _clock()));
  }

  Future<void> _onResume(ResumePomodoro event, Emitter<PomodoroState> emit) async {
    await _update(emit, (s) => PomodoroEngine.resume(s, _clock()));
  }

  Future<void> _onSkip(SkipPomodoroPhase event, Emitter<PomodoroState> emit) async {
    await _update(emit, (s) => PomodoroEngine.skip(s, _repository.getSettings(), _clock()), onWorkStart: true);
  }

  Future<void> _onStartPendingPhase(StartPendingPomodoroPhase event, Emitter<PomodoroState> emit) async {
    await _update(emit, (s) => PomodoroEngine.startPendingPhase(s, _repository.getSettings(), _clock()), onWorkStart: true);
  }

  Future<void> _onStop(StopPomodoro event, Emitter<PomodoroState> emit) async {
    await _run(emit, () async {
      final current = await _advanced();
      if (current != null) await _endSession(current, PomodoroEndReason.manual);
    });
  }

  Future<void> _onUpdateSettings(UpdatePomodoroSettings event, Emitter<PomodoroState> emit) async {
    await _run(emit, () async {
      await _repository.setSettings(event.settings.copyWith(updatedAt: _clock()));
      _syncService?.pushPomodoroSettings().catchError((Object e) => debugPrint('[PomodoroBloc] settings push error: $e'));
    });
  }

  Future<void> _onToggleVisibility(TogglePomodoroVisibility event, Emitter<PomodoroState> emit) async {
    await _run(emit, () => _repository.setShowOnTimeTracking(event.visible));
  }

  Future<void> _onToggleDeviceSounds(TogglePomodoroDeviceSounds event, Emitter<PomodoroState> emit) async {
    await _run(emit, () => _repository.setSoundsOnDevice(event.enabled));
  }

  Future<void> _onToggleDeviceNotifications(TogglePomodoroDeviceNotifications event, Emitter<PomodoroState> emit) async {
    await _run(emit, () async {
      await _repository.setNotificationsOnDevice(event.enabled);
      _scheduledFor = null;
    });
  }

  Future<void> _onRequestPermission(RequestPomodoroPermission event, Emitter<PomodoroState> emit) async {
    await _run(emit, () async {
      await _alerts?.requestPermission();
      await _checkPermission();
      _scheduledFor = null;
    });
  }

  Future<void> _onDeleteRecord(DeletePomodoroRecord event, Emitter<PomodoroState> emit) async {
    await _run(emit, () async {
      await _repository.deleteRecord(event.id);
      _syncService?.deletePomodoroRecord(event.id).catchError((Object e) => debugPrint('[PomodoroBloc] record delete error: $e'));
    });
  }

  Future<void> _onRestoreRecord(RestorePomodoroRecord event, Emitter<PomodoroState> emit) async {
    await _run(emit, () => _fileRecord(event.record));
  }

  Future<void> _onToggleMobileTab(TogglePomodoroMobileTab event, Emitter<PomodoroState> emit) async {
    await _run(emit, () => _repository.setMobileTab(event.enabled));
  }

  Future<void> _fileRecord(PomodoroSessionRecord record) async {
    await _repository.addRecord(record);
    _syncService?.pushPomodoroRecord(record).catchError((Object e) => debugPrint('[PomodoroBloc] record push error: $e'));
  }

  void _onPreviewSound(PreviewPomodoroSound event, Emitter<PomodoroState> emit) {
    _fire(() => _alerts!.preview(event.soundId));
  }

  Future<void> _update(Emitter<PomodoroState> emit, PomodoroSession Function(PomodoroSession) change, {bool onWorkStart = false}) async {
    await _run(emit, () async {
      final current = await _advanced();
      if (current == null) return;
      final next = change(current);
      if (next == current) return;
      await _saveSession(next);
      if (onWorkStart && next.phase == PomodoroPhase.work && next.isRunning) {
        _fire(() => _alerts!.workStarted());
        _warnIfNoTimer();
      }
    });
  }

  void _warnIfNoTimer() {
    if (!_repository.getSettings().warnWhenNoTimer || _runningTimerRepository.hasRunningTimers) return;
    _fire(() => _alerts!.noTimerRunning());
  }

  void _fire(Future<void> Function() alert) {
    if (_alerts == null) return;
    alert().catchError((Object e) => debugPrint('[PomodoroBloc] alert error: $e'));
  }

  Future<void> _checkPermission() async {
    final alerts = _alerts;
    if (alerts == null) return;
    try {
      _permitted = await alerts.permissionGranted();
    } catch (e) {
      debugPrint('[PomodoroBloc] permission check error: $e');
    }
  }

  Future<void> _run(Emitter<PomodoroState> emit, Future<void> Function() action) async {
    try {
      await action();
      await _refresh(emit);
    } catch (e) {
      _emitError(emit, e);
    }
  }

  void _emitError(Emitter<PomodoroState> emit, Object e) {
    debugPrint('[PomodoroBloc] $e');
    emit(_buildState(_repository.getSession(), error: e.toString()));
  }

  /// The stored session brought up to date; persists replayed transitions,
  /// sounds the ones that just happened and files a session that ended by inactivity.
  Future<PomodoroSession?> _advanced() async {
    final live = _repository.getLiveState();
    final stored = live.session;
    if (stored == null) return null;
    final now = _clock();
    final result = PomodoroEngine.advance(stored, _repository.getSettings(), now);
    final record = result.endedRecord;
    if (record != null) {
      await _fileRecord(record);
      await _saveLive(live.ended(record.id, record.endedAt));
      return null;
    }
    final session = result.session!;
    if (session != stored) await _saveSession(session);

    final fresh = result.transitions.where((t) => now.difference(t.at) < _fresh).toList();
    if (fresh.isNotEmpty) {
      final last = fresh.last;
      _fire(() => _alerts!.phaseEnded(last, session));
      if (fresh.any((t) => t.to == PomodoroPhase.work && t.autoStarted)) _warnIfNoTimer();
    }
    return session;
  }

  /// The warning sounds once per phase, when the countdown crosses the threshold.
  void _checkWarning(PomodoroSession? s) {
    if (s == null || !s.isRunning) return;
    final threshold = _repository.getSettings().warningMinutes * 60;
    if (threshold <= 0 || s.phaseDurationSeconds <= threshold) return;
    final remaining = s.remainingSeconds(_clock());
    final phaseKey = '${s.id}:${s.seq}';
    if (remaining > 0 && remaining <= threshold && remaining > threshold - _fresh.inSeconds && _warnedPhase != phaseKey) {
      _warnedPhase = phaseKey;
      _fire(() => _alerts!.warning(s, (threshold / 60).round()));
    }
  }

  void _rescheduleIfChanged(PomodoroSession? s) {
    final key = '${s?.id}:${s?.seq}:${s?.status.name}:${_repository.getSettings().hashCode}:${_repository.getNotificationsOnDevice()}:$_permitted';
    if (key == _scheduledFor) return;
    _scheduledFor = key;
    _fire(() => _alerts!.reschedule(s));
  }

  Future<void> _endSession(PomodoroSession session, PomodoroEndReason reason) async {
    final record = PomodoroEngine.stop(session, _clock(), reason: reason);
    await _fileRecord(record);
    await _saveLive(_repository.getLiveState().ended(session.id, record.endedAt));
  }

  Future<void> _saveSession(PomodoroSession session) => _saveLive(_repository.getLiveState().withSession(session));

  Future<void> _saveLive(PomodoroLiveState live) async {
    await _repository.setLiveState(live);
    _syncService?.pushPomodoroState().catchError((Object e) => debugPrint('[PomodoroBloc] state push error: $e'));
  }

  Future<void> _refresh(Emitter<PomodoroState> emit) async {
    final session = await _advanced();
    _checkWarning(session);
    _rescheduleIfChanged(session);
    emit(_buildState(session));
  }

  PomodoroState _buildState(PomodoroSession? session, {PomodoroSession? startConflict, String? error}) {
    final now = _clock();
    final history = _repository.getRecords();
    return PomodoroState(
      settings: _repository.getSettings(),
      session: session,
      now: now,
      todayCompleted: PomodoroStats.summarize(history, session, PomodoroStats.startOfDay(now), now).pomodoros,
      showOnTimeTracking: _repository.getShowOnTimeTracking(),
      mobileTab: _repository.getMobileTab(),
      history: history,
      soundsOnDevice: _repository.getSoundsOnDevice(),
      notificationsOnDevice: _repository.getNotificationsOnDevice(),
      notificationsPermitted: _permitted,
      startConflict: startConflict,
      errorMessage: error,
    );
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _syncSubscription?.cancel();
    _alertSubscription?.cancel();
    return super.close();
  }
}
