import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';

class SettingsRepository {
  late Box<dynamic> _box;

  Future<void> init() async {
    _box = await Hive.openBox(AppConstants.settingsBox);
  }

  // Theme
  String getThemeMode() => _box.get(AppConstants.themeMode, defaultValue: 'system') as String;
  Future<void> setThemeMode(String mode) => _box.put(AppConstants.themeMode, mode);

  // Language
  String getLanguage() => _box.get(AppConstants.language, defaultValue: 'en') as String;
  Future<void> setLanguage(String lang) => _box.put(AppConstants.language, lang);

  // Time Format
  String getTimeFormat() => _box.get(AppConstants.timeFormat, defaultValue: 'hm') as String;
  Future<void> setTimeFormat(String format) => _box.put(AppConstants.timeFormat, format);

  // Currency
  String getCurrency() => _box.get(AppConstants.currency, defaultValue: AppConstants.defaultCurrency) as String;
  Future<void> setCurrency(String currency) => _box.put(AppConstants.currency, currency);

  // Working Hours
  double getDailyWorkingHours() => (_box.get(AppConstants.dailyWorkingHours, defaultValue: AppConstants.defaultDailyWorkingHours) as num).toDouble();
  Future<void> setDailyWorkingHours(double hours) => _box.put(AppConstants.dailyWorkingHours, hours);

  int getWeeklyWorkingDays() => _box.get(AppConstants.weeklyWorkingDays, defaultValue: AppConstants.defaultWeeklyWorkingDays) as int;
  Future<void> setWeeklyWorkingDays(int days) => _box.put(AppConstants.weeklyWorkingDays, days);

  // Timer Settings
  bool getSimultaneousTimers() => _box.get(AppConstants.simultaneousTimers, defaultValue: false) as bool;
  Future<void> setSimultaneousTimers(bool value) => _box.put(AppConstants.simultaneousTimers, value);

  bool getShowSeconds() => _box.get(AppConstants.showSeconds, defaultValue: true) as bool;
  Future<void> setShowSeconds(bool value) => _box.put(AppConstants.showSeconds, value);

  bool getRoundTime() => _box.get(AppConstants.roundTime, defaultValue: false) as bool;
  Future<void> setRoundTime(bool value) => _box.put(AppConstants.roundTime, value);

  int getRoundToMinutes() => _box.get(AppConstants.roundToMinutes, defaultValue: AppConstants.defaultRoundToMinutes) as int;
  Future<void> setRoundToMinutes(int minutes) => _box.put(AppConstants.roundToMinutes, minutes);

  // Startup & Tray
  bool getLaunchAtStartup() => _box.get(AppConstants.launchAtStartup, defaultValue: false) as bool;
  Future<void> setLaunchAtStartup(bool value) => _box.put(AppConstants.launchAtStartup, value);

  bool getMinimizeToTray() => _box.get(AppConstants.minimizeToTray, defaultValue: true) as bool;
  Future<void> setMinimizeToTray(bool value) => _box.put(AppConstants.minimizeToTray, value);

  // Reminders
  bool getRemindStart() => _box.get(AppConstants.remindStart, defaultValue: false) as bool;
  Future<void> setRemindStart(bool value) => _box.put(AppConstants.remindStart, value);

  bool getRemindStop() => _box.get(AppConstants.remindStop, defaultValue: false) as bool;
  Future<void> setRemindStop(bool value) => _box.put(AppConstants.remindStop, value);

  bool getRemindBreak() => _box.get(AppConstants.remindBreak, defaultValue: false) as bool;
  Future<void> setRemindBreak(bool value) => _box.put(AppConstants.remindBreak, value);

  // Last selected project/task
  String? getLastProjectId() => _box.get(AppConstants.lastProjectId) as String?;
  Future<void> setLastProjectId(String id) => _box.put(AppConstants.lastProjectId, id);

  String? getLastTaskId() => _box.get(AppConstants.lastTaskId) as String?;
  Future<void> setLastTaskId(String id) => _box.put(AppConstants.lastTaskId, id);

  // Allow overlapping time entries
  bool getAllowOverlapTimes() => _box.get(AppConstants.allowOverlapTimes, defaultValue: false) as bool;
  Future<void> setAllowOverlapTimes(bool value) => _box.put(AppConstants.allowOverlapTimes, value);
}
