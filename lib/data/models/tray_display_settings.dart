import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';

/// Which parts of the menu bar title and the tray menu are shown on this device.
class TrayDisplaySettings extends Equatable {
  final bool titlePomodoroIcon;
  final bool titlePomodoroCountdown;
  final bool titlePomodoroRound;
  final bool titleTaskName;
  final bool titleTimerElapsed;
  final bool titleTodayTotal;

  final bool menuPomodoro;
  final bool menuPomodoroWithTimer;
  final bool menuRunningTimers;
  final bool menuRecentTasks;
  final bool menuStartTimer;

  const TrayDisplaySettings({
    this.titlePomodoroIcon = true,
    this.titlePomodoroCountdown = false,
    this.titlePomodoroRound = false,
    this.titleTaskName = true,
    this.titleTimerElapsed = true,
    this.titleTodayTotal = true,
    this.menuPomodoro = true,
    this.menuPomodoroWithTimer = true,
    this.menuRunningTimers = true,
    this.menuRecentTasks = true,
    this.menuStartTimer = true,
  });

  TrayDisplaySettings copyWith({
    bool? titlePomodoroIcon,
    bool? titlePomodoroCountdown,
    bool? titlePomodoroRound,
    bool? titleTaskName,
    bool? titleTimerElapsed,
    bool? titleTodayTotal,
    bool? menuPomodoro,
    bool? menuPomodoroWithTimer,
    bool? menuRunningTimers,
    bool? menuRecentTasks,
    bool? menuStartTimer,
  }) {
    return TrayDisplaySettings(
      titlePomodoroIcon: titlePomodoroIcon ?? this.titlePomodoroIcon,
      titlePomodoroCountdown: titlePomodoroCountdown ?? this.titlePomodoroCountdown,
      titlePomodoroRound: titlePomodoroRound ?? this.titlePomodoroRound,
      titleTaskName: titleTaskName ?? this.titleTaskName,
      titleTimerElapsed: titleTimerElapsed ?? this.titleTimerElapsed,
      titleTodayTotal: titleTodayTotal ?? this.titleTodayTotal,
      menuPomodoro: menuPomodoro ?? this.menuPomodoro,
      menuPomodoroWithTimer: menuPomodoroWithTimer ?? this.menuPomodoroWithTimer,
      menuRunningTimers: menuRunningTimers ?? this.menuRunningTimers,
      menuRecentTasks: menuRecentTasks ?? this.menuRecentTasks,
      menuStartTimer: menuStartTimer ?? this.menuStartTimer,
    );
  }

  Map<String, dynamic> toJson() => {
    'titlePomodoroIcon': titlePomodoroIcon,
    'titlePomodoroCountdown': titlePomodoroCountdown,
    'titlePomodoroRound': titlePomodoroRound,
    'titleTaskName': titleTaskName,
    'titleTimerElapsed': titleTimerElapsed,
    'titleTodayTotal': titleTodayTotal,
    'menuPomodoro': menuPomodoro,
    'menuPomodoroWithTimer': menuPomodoroWithTimer,
    'menuRunningTimers': menuRunningTimers,
    'menuRecentTasks': menuRecentTasks,
    'menuStartTimer': menuStartTimer,
  };

  factory TrayDisplaySettings.fromJson(Map<String, dynamic> json) {
    const d = TrayDisplaySettings();
    bool b(String key, bool fallback) => parseBool(json[key], fallback: fallback);
    return TrayDisplaySettings(
      titlePomodoroIcon: b('titlePomodoroIcon', d.titlePomodoroIcon),
      titlePomodoroCountdown: b('titlePomodoroCountdown', d.titlePomodoroCountdown),
      titlePomodoroRound: b('titlePomodoroRound', d.titlePomodoroRound),
      titleTaskName: b('titleTaskName', d.titleTaskName),
      titleTimerElapsed: b('titleTimerElapsed', d.titleTimerElapsed),
      titleTodayTotal: b('titleTodayTotal', d.titleTodayTotal),
      menuPomodoro: b('menuPomodoro', d.menuPomodoro),
      menuPomodoroWithTimer: b('menuPomodoroWithTimer', d.menuPomodoroWithTimer),
      menuRunningTimers: b('menuRunningTimers', d.menuRunningTimers),
      menuRecentTasks: b('menuRecentTasks', d.menuRecentTasks),
      menuStartTimer: b('menuStartTimer', d.menuStartTimer),
    );
  }

  @override
  List<Object?> get props => [
    titlePomodoroIcon,
    titlePomodoroCountdown,
    titlePomodoroRound,
    titleTaskName,
    titleTimerElapsed,
    titleTodayTotal,
    menuPomodoro,
    menuPomodoroWithTimer,
    menuRunningTimers,
    menuRecentTasks,
    menuStartTimer,
  ];
}
