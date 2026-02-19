import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/running_timer_repository.dart';
import '../../data/repositories/settings_repository.dart';

/// Urgency level for reminder messages.
/// 1 = gentle, 2 = normal, 3 = firm.
enum ReminderUrgency {
  gentle(1),
  normal(2),
  firm(3);

  final int value;
  const ReminderUrgency(this.value);

  static ReminderUrgency fromInt(int v) {
    if (v <= 1) return gentle;
    if (v >= 3) return firm;
    return normal;
  }
}

/// Service that periodically checks work schedule and sends native
/// macOS notifications to remind the user to start/stop tracking or
/// take a break.
///
/// Each reminder type is independently configurable:
///   - enabled/disabled
///   - repeat interval (minutes)
///   - urgency level (gentle / normal / firm)
///
/// Users can "mute today" from the notification action.
class WorkReminderService {
  static const _channel = MethodChannel('com.timer_counter/notifications');

  final SettingsRepository _settingsRepo;
  final RunningTimerRepository _timerRepo;

  Timer? _checkTimer;

  /// Tracks when the last reminder of each type was sent.
  DateTime? _lastStartReminder;
  DateTime? _lastStopReminder;
  DateTime? _lastBreakReminder;

  /// "Don't remind today" flags — set via notification action callback.
  bool _mutedStartToday = false;
  bool _mutedStopToday = false;
  bool _mutedBreakToday = false;

  /// Day for daily reset.
  int _lastResetDay = -1;

  WorkReminderService({required SettingsRepository settingsRepo, required RunningTimerRepository timerRepo}) : _settingsRepo = settingsRepo, _timerRepo = timerRepo;

  /// Start the periodic check (every 60 seconds).
  void start() {
    if (!Platform.isMacOS) return;
    _startAsync();
  }

  Future<void> _startAsync() async {
    debugPrint('[WorkReminder] Starting service...');
    await _requestNotificationPermission();
    await _registerNotificationActions();
    _listenForActions();
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 60), (_) => _check());
    debugPrint('[WorkReminder] Service started, running first check...');
    _check();
  }

  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  void dispose() {
    stop();
  }

  /// Public: mute a specific reminder type for today.
  void muteToday(String type) {
    switch (type) {
      case 'start':
        _mutedStartToday = true;
        debugPrint('[WorkReminder] Muted "start" reminders for today');
        break;
      case 'stop':
        _mutedStopToday = true;
        debugPrint('[WorkReminder] Muted "stop" reminders for today');
        break;
      case 'break':
        _mutedBreakToday = true;
        debugPrint('[WorkReminder] Muted "break" reminders for today');
        break;
    }
  }

  // ── Permission & Action Registration ───────────────────────────────────

  Future<void> _requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (e) {
      debugPrint('[WorkReminder] Permission request failed: $e');
    }
  }

  Future<void> _registerNotificationActions() async {
    try {
      await _channel.invokeMethod('registerActions');
    } catch (e) {
      debugPrint('[WorkReminder] Action registration failed: $e');
    }
  }

  void _listenForActions() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onMuteToday') {
        final type = call.arguments as String?;
        if (type != null) muteToday(type);
      }
    });
  }

  // ── Native notification ────────────────────────────────────────────────

  Future<void> _sendNotification({required String title, required String body, required String identifier, required String categoryIdentifier}) async {
    debugPrint('[WorkReminder] Sending notification: id=$identifier, title=$title');
    try {
      await _channel.invokeMethod('showNotification', {'title': title, 'body': body, 'identifier': identifier, 'categoryIdentifier': categoryIdentifier});
      debugPrint('[WorkReminder] Notification sent successfully: $identifier');
    } catch (e) {
      debugPrint('[WorkReminder] Failed to send notification: $e');
    }
  }

  // ── Core check logic (runs every 60 s) ────────────────────────────────

  void _check() {
    final now = DateTime.now();

    // Reset daily state at midnight.
    if (now.day != _lastResetDay) {
      _lastResetDay = now.day;
      _lastStartReminder = null;
      _lastStopReminder = null;
      _lastBreakReminder = null;
      _mutedStartToday = false;
      _mutedStopToday = false;
      _mutedBreakToday = false;
    }

    final weekday = now.weekday;
    final isWorkDay = _settingsRepo.getWorkScheduleEnabled(weekday);
    if (!isWorkDay) {
      debugPrint('[WorkReminder] Not a work day (weekday=$weekday)');
      return;
    }

    final startTime = _parseTime(_settingsRepo.getWorkScheduleStart(weekday));
    final endTime = _parseTime(_settingsRepo.getWorkScheduleEnd(weekday));
    final nowMinutes = now.hour * 60 + now.minute;
    final hasRunning = _timerRepo.hasRunningTimers;

    debugPrint('[WorkReminder] Check: weekday=$weekday, now=$nowMinutes, start=$startTime, end=$endTime, hasRunning=$hasRunning');
    debugPrint('[WorkReminder] Toggles: remindStart=${_settingsRepo.getRemindStart()}, remindStop=${_settingsRepo.getRemindStop()}, remindBreak=${_settingsRepo.getRemindBreak()}');
    debugPrint('[WorkReminder] Muted: start=$_mutedStartToday, stop=$_mutedStopToday, break=$_mutedBreakToday');

    // 1. Remind to start tracking
    if (_settingsRepo.getRemindStart() && !_mutedStartToday) {
      _checkRemindStart(now, nowMinutes, startTime, endTime, hasRunning);
    }

    // 2. Remind to stop tracking
    if (_settingsRepo.getRemindStop() && !_mutedStopToday) {
      _checkRemindStop(now, nowMinutes, endTime, hasRunning);
    }

    // 3. Remind to take a break
    if (_settingsRepo.getRemindBreak() && !_mutedBreakToday) {
      _checkRemindBreak(now, hasRunning);
    }
  }

  // ── Remind Start ───────────────────────────────────────────────────────

  void _checkRemindStart(DateTime now, int nowMinutes, int startMinutes, int endMinutes, bool hasRunning) {
    if (hasRunning) {
      _lastStartReminder = null;
      debugPrint('[WorkReminder] Start: timer already running, skip');
      return;
    }
    if (nowMinutes < startMinutes || nowMinutes >= endMinutes) {
      debugPrint('[WorkReminder] Start: outside work hours ($nowMinutes not in $startMinutes..$endMinutes)');
      return;
    }

    final interval = _settingsRepo.getRemindStartInterval();
    if (_lastStartReminder != null && now.difference(_lastStartReminder!).inMinutes < interval) {
      debugPrint('[WorkReminder] Start: too soon (interval=${interval}min, last=${_lastStartReminder})');
      return;
    }

    _lastStartReminder = now;
    final urgency = ReminderUrgency.fromInt(_settingsRepo.getRemindStartUrgency());
    final overdueMin = nowMinutes - startMinutes;
    debugPrint('[WorkReminder] Start: SENDING notification (overdue=${overdueMin}min, urgency=$urgency, interval=$interval)');
    final msg = _startMessages(urgency, overdueMin);
    _sendNotification(title: msg.title, body: msg.body, identifier: 'remind_start', categoryIdentifier: 'REMIND_START');
  }

  ({String title, String body}) _startMessages(ReminderUrgency urgency, int overdueMin) {
    final lang = _settingsRepo.getLanguage();
    if (lang == 'cs') {
      switch (urgency) {
        case ReminderUrgency.gentle:
          return (title: '☀️ Dobré ráno!', body: 'Nezapomeň spustit sledování času. Pracovní doba začala před $overdueMin min.');
        case ReminderUrgency.normal:
          return (title: '⏰ Čas pracovat', body: 'Už $overdueMin minut od začátku pracovní doby a žádný časovač neběží.');
        case ReminderUrgency.firm:
          return (title: '🔴 Sledování neběží!', body: 'Už $overdueMin minut bez sledování času! Spusť časovač.');
      }
    } else {
      switch (urgency) {
        case ReminderUrgency.gentle:
          return (title: '☀️ Good morning!', body: 'Work started $overdueMin min ago. Remember to start time tracking.');
        case ReminderUrgency.normal:
          return (title: '⏰ Time to work', body: "It's been $overdueMin minutes since work started and no timer is running.");
        case ReminderUrgency.firm:
          return (title: '🔴 No timer running!', body: '$overdueMin minutes without tracking! Start your timer now.');
      }
    }
  }

  // ── Remind Stop ────────────────────────────────────────────────────────

  void _checkRemindStop(DateTime now, int nowMinutes, int endMinutes, bool hasRunning) {
    if (!hasRunning) {
      _lastStopReminder = null;
      return;
    }
    if (nowMinutes < endMinutes) return;

    final interval = _settingsRepo.getRemindStopInterval();
    if (_lastStopReminder != null && now.difference(_lastStopReminder!).inMinutes < interval) {
      return;
    }

    _lastStopReminder = now;
    final urgency = ReminderUrgency.fromInt(_settingsRepo.getRemindStopUrgency());
    final overtimeMin = nowMinutes - endMinutes;
    final msg = _stopMessages(urgency, overtimeMin);
    _sendNotification(title: msg.title, body: msg.body, identifier: 'remind_stop', categoryIdentifier: 'REMIND_STOP');
  }

  ({String title, String body}) _stopMessages(ReminderUrgency urgency, int overtimeMin) {
    final lang = _settingsRepo.getLanguage();
    if (lang == 'cs') {
      switch (urgency) {
        case ReminderUrgency.gentle:
          return (title: '🏠 Konec pracovní doby', body: 'Pracovní doba skončila. Nezapomeň zastavit časovač.');
        case ReminderUrgency.normal:
          return (title: '⏰ Přesčas: $overtimeMin min', body: 'Časovač stále běží $overtimeMin minut po konci pracovní doby.');
        case ReminderUrgency.firm:
          return (title: '🔴 Časovač stále běží!', body: 'Už $overtimeMin minut přesčas! Nezapomněl jsi zastavit časovač?');
      }
    } else {
      switch (urgency) {
        case ReminderUrgency.gentle:
          return (title: '🏠 End of work day', body: 'Your work hours are over. Remember to stop the timer.');
        case ReminderUrgency.normal:
          return (title: '⏰ Overtime: $overtimeMin min', body: 'Timer still running $overtimeMin minutes past end of work.');
        case ReminderUrgency.firm:
          return (title: '🔴 Timer still running!', body: '$overtimeMin minutes of overtime! Did you forget to stop the timer?');
      }
    }
  }

  // ── Remind Break ───────────────────────────────────────────────────────

  void _checkRemindBreak(DateTime now, bool hasRunning) {
    if (!hasRunning) {
      _lastBreakReminder = null;
      return;
    }

    final timers = _timerRepo.getAll();
    if (timers.isEmpty) return;

    int longestSeconds = 0;
    for (final t in timers) {
      final elapsed = now.difference(t.startTime).inSeconds;
      if (elapsed > longestSeconds) longestSeconds = elapsed;
    }

    final continuousMinutes = longestSeconds ~/ 60;
    final breakAfter = _settingsRepo.getRemindBreakAfter();

    if (continuousMinutes < breakAfter) {
      _lastBreakReminder = null;
      return;
    }

    final interval = _settingsRepo.getRemindBreakInterval();
    if (_lastBreakReminder != null && now.difference(_lastBreakReminder!).inMinutes < interval) {
      return;
    }

    _lastBreakReminder = now;
    final urgency = ReminderUrgency.fromInt(_settingsRepo.getRemindBreakUrgency());
    final hours = continuousMinutes ~/ 60;
    final mins = continuousMinutes % 60;
    final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    final msg = _breakMessages(urgency, durationStr);
    _sendNotification(title: msg.title, body: msg.body, identifier: 'remind_break', categoryIdentifier: 'REMIND_BREAK');
  }

  ({String title, String body}) _breakMessages(ReminderUrgency urgency, String duration) {
    final lang = _settingsRepo.getLanguage();
    if (lang == 'cs') {
      switch (urgency) {
        case ReminderUrgency.gentle:
          return (title: '☕ Pauza?', body: 'Pracuješ už $duration. Co si dát krátkou přestávku?');
        case ReminderUrgency.normal:
          return (title: '☕ Čas na přestávku', body: 'Pracuješ už $duration bez přestávky. Dopřej si pauzu.');
        case ReminderUrgency.firm:
          return (title: '🔴 Přestávka!', body: 'Už $duration nepřetržité práce! Přestávka je důležitá pro zdraví.');
      }
    } else {
      switch (urgency) {
        case ReminderUrgency.gentle:
          return (title: '☕ Break?', body: "You've been working for $duration. How about a short break?");
        case ReminderUrgency.normal:
          return (title: '☕ Time for a break', body: "You've been working for $duration without a break. Take a moment to rest.");
        case ReminderUrgency.firm:
          return (title: '🔴 Take a break!', body: "$duration of continuous work! Breaks are important for your health.");
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  int _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
