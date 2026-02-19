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
  final int remindStartInterval;
  final int remindStartUrgency;
  final bool remindStop;
  final int remindStopInterval;
  final int remindStopUrgency;
  final bool remindBreak;
  final int remindBreakInterval;
  final int remindBreakUrgency;
  final int remindBreakAfter;
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
    this.remindStartInterval = 15,
    this.remindStartUrgency = 2,
    this.remindStop = false,
    this.remindStopInterval = 15,
    this.remindStopUrgency = 2,
    this.remindBreak = false,
    this.remindBreakInterval = 30,
    this.remindBreakUrgency = 2,
    this.remindBreakAfter = 90,
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
    int? remindStartInterval,
    int? remindStartUrgency,
    bool? remindStop,
    int? remindStopInterval,
    int? remindStopUrgency,
    bool? remindBreak,
    int? remindBreakInterval,
    int? remindBreakUrgency,
    int? remindBreakAfter,
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
      remindStartInterval: remindStartInterval ?? this.remindStartInterval,
      remindStartUrgency: remindStartUrgency ?? this.remindStartUrgency,
      remindStop: remindStop ?? this.remindStop,
      remindStopInterval: remindStopInterval ?? this.remindStopInterval,
      remindStopUrgency: remindStopUrgency ?? this.remindStopUrgency,
      remindBreak: remindBreak ?? this.remindBreak,
      remindBreakInterval: remindBreakInterval ?? this.remindBreakInterval,
      remindBreakUrgency: remindBreakUrgency ?? this.remindBreakUrgency,
      remindBreakAfter: remindBreakAfter ?? this.remindBreakAfter,
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
    remindStartInterval,
    remindStartUrgency,
    remindStop,
    remindStopInterval,
    remindStopUrgency,
    remindBreak,
    remindBreakInterval,
    remindBreakUrgency,
    remindBreakAfter,
    allowOverlapTimes,
    workSchedule,
  ];
}
