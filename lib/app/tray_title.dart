import '../data/models/tray_display_settings.dart';

/// The pomodoro as the tray shows it.
class TrayPomodoroInfo {
  final bool isWork;
  final bool isPaused;
  final bool isAwaitingStart;
  final String countdown;
  final int round;
  final int rounds;
  final String phaseLabel;

  const TrayPomodoroInfo({
    required this.isWork,
    required this.isPaused,
    required this.isAwaitingStart,
    required this.countdown,
    required this.round,
    required this.rounds,
    required this.phaseLabel,
  });

  String get icon => isWork ? '🍅' : '☕';
}

class TrayTitle {
  const TrayTitle._();

  /// `[pomodoro] · [task elapsed] | [today]`, each part switchable. With the
  /// default settings and no pomodoro this is the title the app always showed.
  static String build({required TrayDisplaySettings display, required bool timersLoaded, TrayPomodoroInfo? pomodoro, String? taskName, String? elapsed, String? todayTotal}) {
    final (pomodoroPart, running, total) = _split(display, timersLoaded, pomodoro, taskName, elapsed, todayTotal);
    final main = [pomodoroPart, running].where((p) => p.isNotEmpty).join(' · ');
    return [main, total].where((p) => p.isNotEmpty).join(' | ');
  }

  /// The pomodoro and the timer apart, so the macOS menu bar can put the app icon between them:
  /// `[pomodoro] <icon> [task elapsed] | [today]`.
  static ({String pomodoroPart, String timerPart}) parts({
    required TrayDisplaySettings display,
    required bool timersLoaded,
    TrayPomodoroInfo? pomodoro,
    String? taskName,
    String? elapsed,
    String? todayTotal,
  }) {
    final (pomodoroPart, running, total) = _split(display, timersLoaded, pomodoro, taskName, elapsed, todayTotal);
    return (pomodoroPart: pomodoroPart, timerPart: [running, total].where((p) => p.isNotEmpty).join(' | '));
  }

  static (String, String, String) _split(
    TrayDisplaySettings display,
    bool timersLoaded,
    TrayPomodoroInfo? pomodoro,
    String? taskName,
    String? elapsed,
    String? todayTotal,
  ) {
    final pomodoroPart = pomodoro == null ? '' : _pomodoroPart(display, pomodoro);
    final running = [if (display.titleTaskName && taskName != null) taskName, if (display.titleTimerElapsed) elapsed ?? '0:00'].join(' ');
    final total = display.titleTodayTotal && timersLoaded ? (todayTotal ?? '') : '';
    return (pomodoroPart, running, total);
  }

  static String _pomodoroPart(TrayDisplaySettings display, TrayPomodoroInfo p) {
    final parts = <String>[
      if (display.titlePomodoroIcon) p.icon,
      if (display.titlePomodoroCountdown && !p.isAwaitingStart) p.countdown,
      if (display.titlePomodoroRound) '${p.round}/${p.rounds}',
    ];
    if (parts.isEmpty) return '';
    if (p.isPaused) parts.add('⏸');
    if (p.isAwaitingStart) parts.add('▶');
    return parts.join(' ');
  }
}
