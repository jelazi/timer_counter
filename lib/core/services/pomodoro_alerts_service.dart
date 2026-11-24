import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/pomodoro_session.dart';
import '../../data/models/pomodoro_settings.dart';
import '../../data/repositories/pomodoro_repository.dart';
import 'pomodoro_alerts.dart';
import 'pomodoro_engine.dart';

/// macOS shows pomodoro notifications through its own channel because the app
/// delegate already owns the notification centre for the work reminders;
/// Windows, Android and iOS use flutter_local_notifications. On mobile the
/// phase ends are scheduled ahead, so they ring while the app is suspended.
class DefaultPomodoroAlerts implements PomodoroAlerts {
  final PomodoroRepository _repository;

  DefaultPomodoroAlerts({required PomodoroRepository repository}) : _repository = repository;

  static const _macChannel = MethodChannel('com.timer_counter/pomodoro');
  static const _startPendingId = 'start_pending';
  static const _awaitingCategory = 'pomodoro_awaiting';
  static const _phaseNotificationId = 900;
  static const _noTimerNotificationId = 901;
  static const _scheduledIdFloor = 1000000;
  static const _maxScheduled = 20;

  final _plugin = FlutterLocalNotificationsPlugin();
  final _startPending = StreamController<void>.broadcast();
  final _player = AudioPlayer();
  AudioPlayer? _tickPlayer;
  bool _ready = false;
  bool _scheduling = false;

  bool get _isMac => !kIsWeb && Platform.isMacOS;
  bool get _isWindows => !kIsWeb && Platform.isWindows;
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool get _usesPlugin => _isWindows || _isMobile;
  bool get _isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  @override
  Stream<void> get startPendingRequests => _startPending.stream;

  bool _initStarted = false;

  @override
  Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      if (_isMac) {
        _macChannel.setMethodCallHandler((call) async {
          if (call.method == 'onStartPending') _startPending.add(null);
        });
      }
      if (_usesPlugin) {
        await _plugin.initialize(
          settings: InitializationSettings(
            android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestSoundPermission: false,
              requestBadgePermission: false,
              notificationCategories: [
                DarwinNotificationCategory(
                  _awaitingCategory,
                  actions: [
                    DarwinNotificationAction.plain(_startPendingId, tr('pomodoro.notif_action_start'), options: {DarwinNotificationActionOption.foreground}),
                  ],
                ),
              ],
            ),
            windows: const WindowsInitializationSettings(appName: 'Timer Counter', appUserModelId: 'Jelazi.TimerCounter', guid: '6f3c2b0e-8a51-4d7e-9c43-2b7a9e1d5f60'),
          ),
          onDidReceiveNotificationResponse: _onResponse,
        );
        final launch = await _plugin.getNotificationAppLaunchDetails();
        final response = launch?.notificationResponse;
        if ((launch?.didNotificationLaunchApp ?? false) && response != null) _onResponse(response);
      }
      if (!kIsWeb && Platform.isIOS) await _installIosSounds();
      _ready = true;
    } catch (e) {
      debugPrint('[PomodoroAlerts] init failed: $e');
    }
  }

  void _onResponse(NotificationResponse response) {
    if (response.payload == _startPendingId || response.actionId == _startPendingId) _startPending.add(null);
  }

  /// iOS plays a custom notification sound only from the app bundle or Library/Sounds.
  Future<void> _installIosSounds() async {
    final dir = Directory('${(await getLibraryDirectory()).path}/Sounds');
    await dir.create(recursive: true);
    for (final id in PomodoroSounds.selectable) {
      final file = File('${dir.path}/pomodoro_$id.wav');
      if (await file.exists()) continue;
      final data = await rootBundle.load('assets/sounds/$id.wav');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
  }

  // ── Permission ────────────────────────────────────────────────────────

  @override
  Future<void> requestPermission() async {
    if (!_ready || !_isMobile) return;
    try {
      if (Platform.isIOS) {
        await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true);
        return;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      if (!_repository.getExactAlarmsAsked() && !(await android?.canScheduleExactNotifications() ?? true)) {
        await _repository.setExactAlarmsAsked();
        await android?.requestExactAlarmsPermission();
      }
    } catch (e) {
      debugPrint('[PomodoroAlerts] permission request failed: $e');
    }
  }

  @override
  Future<bool> permissionGranted() async {
    if (!_ready || !_isMobile) return true;
    try {
      if (Platform.isIOS) {
        final options = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.checkPermissions();
        return options?.isEnabled ?? false;
      }
      return await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.areNotificationsEnabled() ?? false;
    } catch (e) {
      debugPrint('[PomodoroAlerts] permission check failed: $e');
      return false;
    }
  }

  // ── Events ────────────────────────────────────────────────────────────

  @override
  Future<void> noTimerRunning() => _notify(_noTimerNotificationId, tr('pomodoro.no_timer_title'), tr('pomodoro.no_timer_body'));

  @override
  Future<void> phaseEnded(PomodoroTransition transition, PomodoroSession next) async {
    if (_scheduling) return;
    final settings = _repository.getSettings();
    await _play(settings.soundFor(soundEventForEnd(transition.from)), settings.volume);
    await _notify(
      _phaseNotificationId,
      _phaseEndTitle(transition.from),
      _phaseEndBody(next.phase, next.isAwaitingStart, next.phaseDurationSeconds ~/ 60),
      awaiting: next.isAwaitingStart,
    );
  }

  @override
  Future<void> workStarted() async {
    final settings = _repository.getSettings();
    await _play(settings.soundWorkStart, settings.volume);
  }

  @override
  Future<void> warning(PomodoroSession session, int minutesLeft) async {
    if (_scheduling) return;
    final settings = _repository.getSettings();
    await _play(settings.soundWarning, settings.volume);
  }

  @override
  Future<void> tick() async {
    if (!_isDesktop || !_repository.getSoundsOnDevice()) return;
    try {
      final player = _tickPlayer ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      await player.setVolume(_repository.getSettings().volume * 0.5);
      await player.play(AssetSource('sounds/${PomodoroSounds.tick}.wav'));
    } catch (e) {
      debugPrint('[PomodoroAlerts] tick failed: $e');
    }
  }

  @override
  Future<void> preview(String soundId) => _play(soundId, _repository.getSettings().volume, force: true);

  // ── Scheduling (mobile) ───────────────────────────────────────────────

  @override
  Future<void> reschedule(PomodoroSession? session) async {
    if (!_ready || !_isMobile) return;
    try {
      // Only still-pending ones: cancelling a delivered notification would pull it off the screen.
      for (final pending in await _plugin.pendingNotificationRequests()) {
        if (pending.id >= _scheduledIdFloor) await _plugin.cancel(id: pending.id);
      }
      _scheduling = false;
      if (session == null || !_repository.getNotificationsOnDevice() || !await permissionGranted()) return;

      final settings = _repository.getSettings();
      final plan = PomodoroAlertPlan.upcoming(session, settings, DateTime.now()).take(_maxScheduled).toList();
      final mode = await _androidScheduleMode();
      for (var i = 0; i < plan.length; i++) {
        final alert = plan[i];
        final isWarning = alert.kind == PlannedAlertKind.warning;
        await _plugin.zonedSchedule(
          id: _scheduledId(alert.at, alert.kind),
          scheduledDate: tz.TZDateTime.from(alert.at.toUtc(), tz.UTC),
          title: isWarning ? tr('pomodoro.notif_warning', namedArgs: {'minutes': '${alert.minutesLeft}'}) : _phaseEndTitle(alert.phase),
          body: isWarning ? _phaseLabel(alert.phase) : _phaseEndBody(alert.nextPhase!, alert.nextAwaiting, alert.nextMinutes),
          notificationDetails: _details(settings.soundFor(alert.soundEvent), awaiting: !isWarning && alert.nextAwaiting),
          androidScheduleMode: mode,
          payload: !isWarning && alert.nextAwaiting ? _startPendingId : null,
        );
      }
      _scheduling = true;
    } catch (e) {
      debugPrint('[PomodoroAlerts] scheduling failed: $e');
    }
  }

  static int _scheduledId(DateTime at, PlannedAlertKind kind) => _scheduledIdFloor + (at.millisecondsSinceEpoch ~/ 1000 * 2 + kind.index) % 1000000000;

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    final exact = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.canScheduleExactNotifications() ?? false;
    return exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Future<void> _play(String soundId, double volume, {bool force = false}) async {
    if (soundId == PomodoroSounds.none || (!force && !_repository.getSoundsOnDevice())) return;
    try {
      await _player.stop();
      await _player.setVolume(volume);
      await _player.play(AssetSource('sounds/$soundId.wav'));
    } catch (e) {
      debugPrint('[PomodoroAlerts] sound failed: $e');
    }
  }

  Future<void> _notify(int id, String title, String body, {bool awaiting = false}) async {
    if (!_ready || !_repository.getNotificationsOnDevice()) return;
    try {
      if (_isMac) {
        await _macChannel.invokeMethod('show', {'title': title, 'body': body, 'identifier': id == _phaseNotificationId ? 'pomodoro_phase' : 'pomodoro_$id', 'awaiting': awaiting});
      } else if (_usesPlugin) {
        await _plugin.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: _details(PomodoroSounds.none, awaiting: awaiting),
          payload: awaiting ? _startPendingId : null,
        );
      }
    } catch (e) {
      debugPrint('[PomodoroAlerts] notification failed: $e');
    }
  }

  /// One Android channel per sound: a channel's sound cannot change once created.
  NotificationDetails _details(String soundId, {required bool awaiting}) {
    final silent = soundId == PomodoroSounds.none;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        silent ? 'pomodoro_silent' : 'pomodoro_$soundId',
        silent ? 'Pomodoro' : 'Pomodoro ($soundId)',
        importance: Importance.high,
        priority: Priority.high,
        playSound: !silent,
        sound: silent ? null : RawResourceAndroidNotificationSound('pomodoro_$soundId'),
        actions: awaiting ? [AndroidNotificationAction(_startPendingId, tr('pomodoro.notif_action_start'), showsUserInterface: true)] : null,
      ),
      iOS: DarwinNotificationDetails(presentSound: !silent, sound: silent ? null : 'pomodoro_$soundId.wav', categoryIdentifier: awaiting ? _awaitingCategory : null),
      windows: WindowsNotificationDetails(audio: WindowsNotificationAudio.silent()),
    );
  }

  String _phaseLabel(PomodoroPhase phase) => switch (phase) {
    PomodoroPhase.work => tr('pomodoro.phase_work'),
    PomodoroPhase.shortBreak => tr('pomodoro.phase_short_break'),
    PomodoroPhase.longBreak => tr('pomodoro.phase_long_break'),
  };

  String _phaseEndTitle(PomodoroPhase ending) => switch (ending) {
    PomodoroPhase.work => tr('pomodoro.notif_work_done'),
    PomodoroPhase.shortBreak => tr('pomodoro.notif_break_done'),
    PomodoroPhase.longBreak => tr('pomodoro.notif_cycle_done'),
  };

  String _phaseEndBody(PomodoroPhase next, bool awaiting, int minutes) {
    if (awaiting) return tr(next == PomodoroPhase.work ? 'pomodoro.notif_tap_start_work' : 'pomodoro.notif_tap_start_break');
    return tr(next == PomodoroPhase.work ? 'pomodoro.notif_work_running' : 'pomodoro.notif_break_running', namedArgs: {'minutes': '$minutes'});
  }
}
