import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/firebase_sync_service_v2.dart';
import '../../../data/models/running_timer_model.dart';
import '../../../data/models/time_entry_model.dart';
import '../../../data/repositories/running_timer_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/time_entry_repository.dart';
import 'timer_event.dart';
import 'timer_state.dart';

class TimerBloc extends Bloc<TimerEvent, TimerState> {
  final RunningTimerRepository _runningTimerRepository;
  final TimeEntryRepository _timeEntryRepository;
  final SettingsRepository _settingsRepository;
  final FirebaseSyncService? _firebaseSyncService;
  Timer? _ticker;
  StreamSubscription? _syncSubscription;
  final _uuid = const Uuid();

  TimerBloc({
    required RunningTimerRepository runningTimerRepository,
    required TimeEntryRepository timeEntryRepository,
    required SettingsRepository settingsRepository,
    FirebaseSyncService? firebaseSyncService,
  }) : _runningTimerRepository = runningTimerRepository,
       _timeEntryRepository = timeEntryRepository,
       _settingsRepository = settingsRepository,
       _firebaseSyncService = firebaseSyncService,
       super(const TimerInitial()) {
    on<LoadRunningTimers>(_onLoadRunningTimers);
    on<StartTimer>(_onStartTimer);
    on<StopTimer>(_onStopTimer);
    on<StopAllTimers>(_onStopAllTimers);
    on<TickTimers>(_onTickTimers);
    on<UpdateTimerNotes>(_onUpdateTimerNotes);
    on<SyncTimersChanged>(_onSyncTimersChanged);

    _startTicker();
    _startSyncListener();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      add(const TickTimers());
    });
  }

  /// Listen to Firestore sync events for running timers and time entries.
  void _startSyncListener() {
    if (_firebaseSyncService == null) return;
    _syncSubscription = _firebaseSyncService.onCollectionChanged.listen((col) {
      if (col == SyncCollection.runningTimers || col == SyncCollection.timeEntries) {
        add(const SyncTimersChanged());
      }
    });
  }

  void _onLoadRunningTimers(LoadRunningTimers event, Emitter<TimerState> emit) {
    _emitCurrentState(emit);
  }

  Future<void> _onStartTimer(StartTimer event, Emitter<TimerState> emit) async {
    try {
      final allowSimultaneous = _settingsRepository.getSimultaneousTimers();

      // If simultaneous timers not allowed, stop all running timers first
      if (!allowSimultaneous) {
        final runningTimers = _runningTimerRepository.getAll();
        for (final timer in runningTimers) {
          await _stopAndSaveTimer(timer);
        }
      }

      final timer = RunningTimerModel(id: _uuid.v4(), projectId: event.projectId, taskId: event.taskId, startTime: DateTime.now(), notes: event.notes);

      await _runningTimerRepository.start(timer);
      // Push to Firebase
      _firebaseSyncService?.pushRunningTimer(timer).catchError((e) => debugPrint('[TimerBloc] sync push error: $e'));
      _emitCurrentState(emit);
    } catch (e) {
      emit(TimerError(e.toString()));
    }
  }

  Future<void> _onStopTimer(StopTimer event, Emitter<TimerState> emit) async {
    try {
      final timer = _runningTimerRepository.getById(event.timerId);
      if (timer != null) {
        await _stopAndSaveTimer(timer);
      }
      _emitCurrentState(emit);
    } catch (e) {
      emit(TimerError(e.toString()));
    }
  }

  Future<void> _onStopAllTimers(StopAllTimers event, Emitter<TimerState> emit) async {
    try {
      final runningTimers = _runningTimerRepository.getAll();
      for (final timer in runningTimers) {
        await _stopAndSaveTimer(timer);
      }
      _emitCurrentState(emit);
    } catch (e) {
      emit(TimerError(e.toString()));
    }
  }

  void _onTickTimers(TickTimers event, Emitter<TimerState> emit) {
    _emitCurrentState(emit);
  }

  /// Handle sync event: remote running timers or time entries changed.
  void _onSyncTimersChanged(SyncTimersChanged event, Emitter<TimerState> emit) {
    _emitCurrentState(emit);
  }

  Future<void> _onUpdateTimerNotes(UpdateTimerNotes event, Emitter<TimerState> emit) async {
    try {
      await _runningTimerRepository.updateNotes(event.timerId, event.notes);
      _emitCurrentState(emit);
    } catch (e) {
      emit(TimerError(e.toString()));
    }
  }

  Future<void> _stopAndSaveTimer(RunningTimerModel timer) async {
    final now = DateTime.now();
    final entry = TimeEntryModel(
      id: _uuid.v4(),
      projectId: timer.projectId,
      taskId: timer.taskId,
      startTime: timer.startTime,
      endTime: now,
      durationSeconds: now.difference(timer.startTime).inSeconds,
      notes: timer.notes,
      createdAt: DateTime.now(),
    );

    await _timeEntryRepository.add(entry);
    await _runningTimerRepository.stop(timer.id);

    // Push to Firebase
    _firebaseSyncService?.pushTimeEntry(entry).catchError((e) => debugPrint('[TimerBloc] sync push error: $e'));
    _firebaseSyncService?.deleteRunningTimer(timer.id).catchError((e) => debugPrint('[TimerBloc] sync delete error: $e'));
  }

  void _emitCurrentState(Emitter<TimerState> emit) {
    final runningTimers = _runningTimerRepository.getAll();
    final todayEntries = _timeEntryRepository.getToday();
    final completedSeconds = todayEntries.fold(0, (sum, e) => sum + e.actualDurationSeconds);
    final runningSeconds = runningTimers.fold(0, (sum, t) => sum + t.elapsedSeconds);

    emit(TimerRunning(runningTimers: runningTimers, todayEntries: todayEntries, totalTodaySeconds: completedSeconds + runningSeconds));
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _syncSubscription?.cancel();
    return super.close();
  }
}
