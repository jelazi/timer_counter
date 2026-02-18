import 'package:equatable/equatable.dart';

class SettingsState extends Equatable {
  final String themeMode;
  final String language;
  final String timeFormat;
  final String currency;
  final double dailyWorkingHours;
  final int weeklyWorkingDays;
  final bool simultaneousTimers;
  final bool showSeconds;
  final bool roundTime;
  final int roundToMinutes;
  final bool launchAtStartup;
  final bool minimizeToTray;
  final bool remindStart;
  final bool remindStop;
  final bool remindBreak;
  final bool allowOverlapTimes;
  final Map<int, ({String start, String end, bool enabled})> workSchedule;

  const SettingsState({
    this.themeMode = 'system',
    this.language = 'en',
    this.timeFormat = 'hm',
    this.currency = 'CZK',
    this.dailyWorkingHours = 8.0,
    this.weeklyWorkingDays = 5,
    this.simultaneousTimers = false,
    this.showSeconds = true,
    this.roundTime = false,
    this.roundToMinutes = 5,
    this.launchAtStartup = false,
    this.minimizeToTray = true,
    this.remindStart = false,
    this.remindStop = false,
    this.remindBreak = false,
    this.allowOverlapTimes = false,
    this.workSchedule = const {},
  });

  SettingsState copyWith({
    String? themeMode,
    String? language,
    String? timeFormat,
    String? currency,
    double? dailyWorkingHours,
    int? weeklyWorkingDays,
    bool? simultaneousTimers,
    bool? showSeconds,
    bool? roundTime,
    int? roundToMinutes,
    bool? launchAtStartup,
    bool? minimizeToTray,
    bool? remindStart,
    bool? remindStop,
    bool? remindBreak,
    bool? allowOverlapTimes,
    Map<int, ({String start, String end, bool enabled})>? workSchedule,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      timeFormat: timeFormat ?? this.timeFormat,
      currency: currency ?? this.currency,
      dailyWorkingHours: dailyWorkingHours ?? this.dailyWorkingHours,
      weeklyWorkingDays: weeklyWorkingDays ?? this.weeklyWorkingDays,
      simultaneousTimers: simultaneousTimers ?? this.simultaneousTimers,
      showSeconds: showSeconds ?? this.showSeconds,
      roundTime: roundTime ?? this.roundTime,
      roundToMinutes: roundToMinutes ?? this.roundToMinutes,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      remindStart: remindStart ?? this.remindStart,
      remindStop: remindStop ?? this.remindStop,
      remindBreak: remindBreak ?? this.remindBreak,
      allowOverlapTimes: allowOverlapTimes ?? this.allowOverlapTimes,
      workSchedule: workSchedule ?? this.workSchedule,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    language,
    timeFormat,
    currency,
    dailyWorkingHours,
    weeklyWorkingDays,
    simultaneousTimers,
    showSeconds,
    roundTime,
    roundToMinutes,
    launchAtStartup,
    minimizeToTray,
    remindStart,
    remindStop,
    remindBreak,
    allowOverlapTimes,
    workSchedule,
  ];
}
