import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../models/invoice_settings.dart';
import '../models/work_day_schedule.dart';

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
  // Remind Start
  bool getRemindStart() => _box.get(AppConstants.remindStart, defaultValue: false) as bool;
  Future<void> setRemindStart(bool value) => _box.put(AppConstants.remindStart, value);
  int getRemindStartInterval() => _box.get(AppConstants.remindStartInterval, defaultValue: AppConstants.defaultReminderInterval) as int;
  Future<void> setRemindStartInterval(int minutes) => _box.put(AppConstants.remindStartInterval, minutes);
  int getRemindStartUrgency() => _box.get(AppConstants.remindStartUrgency, defaultValue: AppConstants.defaultReminderUrgency) as int;
  Future<void> setRemindStartUrgency(int level) => _box.put(AppConstants.remindStartUrgency, level);

  // Remind Stop
  bool getRemindStop() => _box.get(AppConstants.remindStop, defaultValue: false) as bool;
  Future<void> setRemindStop(bool value) => _box.put(AppConstants.remindStop, value);
  int getRemindStopInterval() => _box.get(AppConstants.remindStopInterval, defaultValue: AppConstants.defaultReminderInterval) as int;
  Future<void> setRemindStopInterval(int minutes) => _box.put(AppConstants.remindStopInterval, minutes);
  int getRemindStopUrgency() => _box.get(AppConstants.remindStopUrgency, defaultValue: AppConstants.defaultReminderUrgency) as int;
  Future<void> setRemindStopUrgency(int level) => _box.put(AppConstants.remindStopUrgency, level);

  // Remind Break
  bool getRemindBreak() => _box.get(AppConstants.remindBreak, defaultValue: false) as bool;
  Future<void> setRemindBreak(bool value) => _box.put(AppConstants.remindBreak, value);
  int getRemindBreakInterval() => _box.get(AppConstants.remindBreakInterval, defaultValue: 30) as int;
  Future<void> setRemindBreakInterval(int minutes) => _box.put(AppConstants.remindBreakInterval, minutes);
  int getRemindBreakUrgency() => _box.get(AppConstants.remindBreakUrgency, defaultValue: AppConstants.defaultReminderUrgency) as int;
  Future<void> setRemindBreakUrgency(int level) => _box.put(AppConstants.remindBreakUrgency, level);
  int getRemindBreakAfter() => _box.get(AppConstants.remindBreakAfter, defaultValue: AppConstants.defaultBreakAfter) as int;
  Future<void> setRemindBreakAfter(int minutes) => _box.put(AppConstants.remindBreakAfter, minutes);

  // Last selected project/task
  String? getLastProjectId() => _box.get(AppConstants.lastProjectId) as String?;
  Future<void> setLastProjectId(String id) => _box.put(AppConstants.lastProjectId, id);

  String? getLastTaskId() => _box.get(AppConstants.lastTaskId) as String?;
  Future<void> setLastTaskId(String id) => _box.put(AppConstants.lastTaskId, id);

  // Recent tasks (last 4 used project+task pairs)
  static const int _maxRecentTasks = 4;

  List<Map<String, String>> getRecentTasks() {
    final raw = _box.get(AppConstants.recentTasks);
    if (raw == null) return [];
    return (raw as List).map((e) {
      final map = Map<dynamic, dynamic>.from(e as Map);
      return map.map((k, v) => MapEntry(k.toString(), v.toString()));
    }).toList();
  }

  Future<void> addRecentTask(String projectId, String taskId) async {
    final recent = getRecentTasks();
    // Remove duplicate if exists
    recent.removeWhere((e) => e['projectId'] == projectId && e['taskId'] == taskId);
    // Insert at front
    recent.insert(0, {'projectId': projectId, 'taskId': taskId});
    // Keep max 4
    if (recent.length > _maxRecentTasks) {
      recent.removeRange(_maxRecentTasks, recent.length);
    }
    await _box.put(AppConstants.recentTasks, recent);
  }

  // Allow overlapping time entries
  bool getAllowOverlapTimes() => _box.get(AppConstants.allowOverlapTimes, defaultValue: false) as bool;
  Future<void> setAllowOverlapTimes(bool value) => _box.put(AppConstants.allowOverlapTimes, value);

  // === Invoice Settings ===

  // Suppliers list
  List<InvoiceParty> getSuppliers() {
    final raw = _box.get(AppConstants.invoiceSuppliers);
    if (raw == null) return [];
    return (raw as List).map((e) => InvoiceParty.fromJson(Map<dynamic, dynamic>.from(e as Map))).toList();
  }

  Future<void> setSuppliers(List<InvoiceParty> suppliers) => _box.put(AppConstants.invoiceSuppliers, suppliers.map((s) => s.toJson()).toList());

  Future<void> addSupplier(InvoiceParty supplier) async {
    final list = getSuppliers();
    list.add(supplier);
    await setSuppliers(list);
  }

  Future<void> removeSupplierAt(int index) async {
    final list = getSuppliers();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await setSuppliers(list);
    }
  }

  int getSelectedSupplierIndex() => _box.get(AppConstants.invoiceSelectedSupplierIndex, defaultValue: -1) as int;
  Future<void> setSelectedSupplierIndex(int index) => _box.put(AppConstants.invoiceSelectedSupplierIndex, index);

  // Customers list
  List<InvoiceParty> getCustomers() {
    final raw = _box.get(AppConstants.invoiceCustomers);
    if (raw == null) return [];
    return (raw as List).map((e) => InvoiceParty.fromJson(Map<dynamic, dynamic>.from(e as Map))).toList();
  }

  Future<void> setCustomers(List<InvoiceParty> customers) => _box.put(AppConstants.invoiceCustomers, customers.map((c) => c.toJson()).toList());

  Future<void> addCustomer(InvoiceParty customer) async {
    final list = getCustomers();
    list.add(customer);
    await setCustomers(list);
  }

  Future<void> removeCustomerAt(int index) async {
    final list = getCustomers();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await setCustomers(list);
    }
  }

  int getSelectedCustomerIndex() => _box.get(AppConstants.invoiceSelectedCustomerIndex, defaultValue: -1) as int;
  Future<void> setSelectedCustomerIndex(int index) => _box.put(AppConstants.invoiceSelectedCustomerIndex, index);

  // Invoice description
  String getInvoiceDescription() => _box.get(AppConstants.invoiceDescription, defaultValue: '') as String;
  Future<void> setInvoiceDescription(String desc) => _box.put(AppConstants.invoiceDescription, desc);

  // Bank info
  String getInvoiceBankName() => _box.get(AppConstants.invoiceBankName, defaultValue: '') as String;
  Future<void> setInvoiceBankName(String v) => _box.put(AppConstants.invoiceBankName, v);

  String getInvoiceBankCode() => _box.get(AppConstants.invoiceBankCode, defaultValue: '') as String;
  Future<void> setInvoiceBankCode(String v) => _box.put(AppConstants.invoiceBankCode, v);

  String getInvoiceSwift() => _box.get(AppConstants.invoiceSwift, defaultValue: '') as String;
  Future<void> setInvoiceSwift(String v) => _box.put(AppConstants.invoiceSwift, v);

  String getInvoiceAccountNumber() => _box.get(AppConstants.invoiceAccountNumber, defaultValue: '') as String;
  Future<void> setInvoiceAccountNumber(String v) => _box.put(AppConstants.invoiceAccountNumber, v);

  String getInvoiceIban() => _box.get(AppConstants.invoiceIban, defaultValue: '') as String;
  Future<void> setInvoiceIban(String v) => _box.put(AppConstants.invoiceIban, v);

  // Issuer
  String getInvoiceIssuerName() => _box.get(AppConstants.invoiceIssuerName, defaultValue: '') as String;
  Future<void> setInvoiceIssuerName(String v) => _box.put(AppConstants.invoiceIssuerName, v);

  String getInvoiceIssuerEmail() => _box.get(AppConstants.invoiceIssuerEmail, defaultValue: '') as String;
  Future<void> setInvoiceIssuerEmail(String v) => _box.put(AppConstants.invoiceIssuerEmail, v);

  // File names
  String getInvoiceReportFilename() => _box.get(AppConstants.invoiceReportFilename, defaultValue: 'report_{month}_{year}') as String;
  Future<void> setInvoiceReportFilename(String v) => _box.put(AppConstants.invoiceReportFilename, v);

  String getInvoiceReportRezijniFilename() => _box.get(AppConstants.invoiceReportRezijniFilename, defaultValue: 'report_{month}_{year}_rezijni') as String;
  Future<void> setInvoiceReportRezijniFilename(String v) => _box.put(AppConstants.invoiceReportRezijniFilename, v);

  String getInvoiceInvoiceFilename() => _box.get(AppConstants.invoiceInvoiceFilename, defaultValue: 'faktura_{month}_{year}') as String;
  Future<void> setInvoiceInvoiceFilename(String v) => _box.put(AppConstants.invoiceInvoiceFilename, v);

  // === PocketBase Sync Settings ===

  String getPocketBaseUrl() => _box.get(AppConstants.pocketBaseUrl, defaultValue: '') as String;
  Future<void> setPocketBaseUrl(String v) => _box.put(AppConstants.pocketBaseUrl, v);

  String getPocketBaseEmail() => _box.get(AppConstants.pocketBaseEmail, defaultValue: '') as String;
  Future<void> setPocketBaseEmail(String v) => _box.put(AppConstants.pocketBaseEmail, v);

  String getPocketBasePassword() => _box.get(AppConstants.pocketBasePassword, defaultValue: '') as String;
  Future<void> setPocketBasePassword(String v) => _box.put(AppConstants.pocketBasePassword, v);

  String getPocketBaseAuthToken() => _box.get(AppConstants.pocketBaseAuthToken, defaultValue: '') as String;
  Future<void> setPocketBaseAuthToken(String v) => _box.put(AppConstants.pocketBaseAuthToken, v);

  String getPocketBaseAuthModel() => _box.get(AppConstants.pocketBaseAuthModel, defaultValue: '') as String;
  Future<void> setPocketBaseAuthModel(String v) => _box.put(AppConstants.pocketBaseAuthModel, v);

  bool getPocketBaseEnabled() => _box.get(AppConstants.pocketBaseEnabled, defaultValue: false) as bool;
  Future<void> setPocketBaseEnabled(bool v) => _box.put(AppConstants.pocketBaseEnabled, v);

  String getPocketBaseLastSync() => _box.get(AppConstants.pocketBaseLastSync, defaultValue: '') as String;
  Future<void> setPocketBaseLastSync(String v) => _box.put(AppConstants.pocketBaseLastSync, v);

  /// PocketBase user id the local store belongs to. Empty before the first sign-in.
  String getPocketBaseOwnerId() => _box.get(AppConstants.pocketBaseOwnerId, defaultValue: '') as String;
  Future<void> setPocketBaseOwnerId(String v) => _box.put(AppConstants.pocketBaseOwnerId, v);

  bool get hasPocketBaseOverride => getPocketBaseUrl().isNotEmpty || getPocketBaseEmail().isNotEmpty || getPocketBasePassword().isNotEmpty;

  Future<void> clearPocketBaseOverride() async {
    await setPocketBaseUrl('');
    await setPocketBaseEmail('');
    await setPocketBasePassword('');
  }

  bool get isPocketBaseConfigured => getPocketBaseUrl().isNotEmpty;

  // === PDF Report Project Filter ===

  List<String> getPdfReportProjectIds() {
    final raw = _box.get(AppConstants.pdfReportProjectIds);
    if (raw == null) return [];
    return (raw as List).cast<String>();
  }

  Future<void> setPdfReportProjectIds(List<String> ids) => _box.put(AppConstants.pdfReportProjectIds, ids);

  // === Work Schedule (per weekday) ===
  // Day: 1=Monday .. 7=Sunday
  // Store: work_schedule_<day>_start, work_schedule_<day>_end, work_schedule_<day>_enabled

  static const _defaultSchedule = {
    1: ('08:00', '16:30', true), // Monday
    2: ('08:00', '16:30', true), // Tuesday
    3: ('08:00', '16:30', true), // Wednesday
    4: ('08:00', '16:30', true), // Thursday
    5: ('08:00', '16:30', true), // Friday
    6: ('08:00', '12:00', false), // Saturday
    7: ('08:00', '12:00', false), // Sunday
  };

  String getWorkScheduleStart(int weekday) => _box.get('${AppConstants.workSchedulePrefix}_${weekday}_start', defaultValue: _defaultSchedule[weekday]!.$1) as String;
  Future<void> setWorkScheduleStart(int weekday, String time) => _box.put('${AppConstants.workSchedulePrefix}_${weekday}_start', time);

  String getWorkScheduleEnd(int weekday) => _box.get('${AppConstants.workSchedulePrefix}_${weekday}_end', defaultValue: _defaultSchedule[weekday]!.$2) as String;
  Future<void> setWorkScheduleEnd(int weekday, String time) => _box.put('${AppConstants.workSchedulePrefix}_${weekday}_end', time);

  bool getWorkScheduleEnabled(int weekday) => _box.get('${AppConstants.workSchedulePrefix}_${weekday}_enabled', defaultValue: _defaultSchedule[weekday]!.$3) as bool;
  Future<void> setWorkScheduleEnabled(int weekday, bool enabled) => _box.put('${AppConstants.workSchedulePrefix}_${weekday}_enabled', enabled);

  WorkDaySchedule getWorkDaySchedule(int weekday) =>
      WorkDaySchedule(start: getWorkScheduleStart(weekday), end: getWorkScheduleEnd(weekday), enabled: getWorkScheduleEnabled(weekday));

  Future<void> setWorkDaySchedule(int weekday, WorkDaySchedule schedule) async {
    await setWorkScheduleStart(weekday, schedule.start);
    await setWorkScheduleEnd(weekday, schedule.end);
    await setWorkScheduleEnabled(weekday, schedule.enabled);
  }

  Map<String, dynamic> getWorkScheduleMap() => {for (int day = 1; day <= 7; day++) '$day': getWorkDaySchedule(day).toJson()};

  Future<void> restoreWorkScheduleMap(Map<dynamic, dynamic> schedule) async {
    for (int day = 1; day <= 7; day++) {
      final raw = schedule['$day'];
      if (raw is Map) await setWorkDaySchedule(day, WorkDaySchedule.fromJson(raw));
    }
  }

  /// Get today's expected working hours (0 if not a work day), considering day overrides
  double getTodayExpectedHours() {
    return getExpectedHoursForDate(DateTime.now());
  }

  /// Get expected working hours for a specific weekday
  double getExpectedHoursForDay(int weekday) {
    final schedule = getWorkDaySchedule(weekday);
    return schedule.enabled ? schedule.hours : 0;
  }

  // === Local Snapshot Backups ===

  /// How often an automatic local snapshot is taken: 'off', 'launch', 'daily', 'weekly'.
  String getSnapshotFrequency() => _box.get(AppConstants.snapshotFrequency, defaultValue: AppConstants.defaultSnapshotFrequency) as String;
  Future<void> setSnapshotFrequency(String value) => _box.put(AppConstants.snapshotFrequency, value);

  int getSnapshotRetentionDays() => _box.get(AppConstants.snapshotRetentionDays, defaultValue: AppConstants.defaultSnapshotRetentionDays) as int;
  Future<void> setSnapshotRetentionDays(int value) => _box.put(AppConstants.snapshotRetentionDays, value);

  /// Date of the most recent snapshot as 'YYYY-MM-DD', or empty if none taken.
  String getLastSnapshotDate() => _box.get(AppConstants.lastSnapshotDate, defaultValue: '') as String;
  Future<void> setLastSnapshotDate(String value) => _box.put(AppConstants.lastSnapshotDate, value);

  // === Day Overrides (per specific date) ===
  // 'off' = vacation/day off (normally a work day but won't work)
  // 'work' = extra work day (normally not a work day but will work)

  static String _dayOverrideKey(DateTime date) => '${AppConstants.dayOverridePrefix}_${_dateKey(date)}';

  /// Get override for a specific date. Returns 'off', 'work', or null (no override).
  String? getDayOverride(DateTime date) {
    return _box.get(_dayOverrideKey(date)) as String?;
  }

  /// Set or remove override for a specific date.
  Future<void> setDayOverride(DateTime date, String? type) async {
    final key = _dayOverrideKey(date);
    if (type == null) {
      await _box.delete(key);
    } else {
      await _box.put(key, type);
    }
  }

  /// Get all day overrides for a specific month.
  Map<DateTime, String> getDayOverridesForMonth(int year, int month) {
    final result = <DateTime, String>{};
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final override = getDayOverride(date);
      if (override != null) {
        result[date] = override;
      }
    }
    return result;
  }

  /// Get all day overrides (for backup). Returns map of 'YYYY-MM-DD' → 'off'/'work'.
  Map<String, String> getAllDayOverrides() {
    final result = <String, String>{};
    final prefix = '${AppConstants.dayOverridePrefix}_';
    for (final key in _box.keys) {
      if (key is String && key.startsWith(prefix)) {
        final value = _box.get(key);
        if (value is String) {
          result[key.substring(prefix.length)] = value;
        }
      }
    }
    return result;
  }

  /// Restore all day overrides from backup. Input: map of 'YYYY-MM-DD' → 'off'/'work'.
  Future<void> restoreAllDayOverrides(Map<String, String> overrides) async {
    // Clear existing overrides first
    final prefix = '${AppConstants.dayOverridePrefix}_';
    final keysToDelete = _box.keys.where((k) => k is String && k.startsWith(prefix)).toList();
    for (final key in keysToDelete) {
      await _box.delete(key);
    }
    // Set new overrides
    for (final entry in overrides.entries) {
      await _box.put('$prefix${entry.key}', entry.value);
    }
  }

  // === Work Contexts ===
  //
  // A work context is a monthly target (see MonthlyHoursTargetModel) that also
  // carries its own schedule, day overrides and per-month hour goals. Everything
  // here is optional: a context without its own settings behaves exactly as
  // before, falling back to the global schedule and overrides.

  static String _contextScheduleKey(String contextId, int weekday, String field) => '${AppConstants.contextSchedulePrefix}_${contextId}_${weekday}_$field';

  static String _contextOwnScheduleKey(String contextId) => '${AppConstants.contextSchedulePrefix}_${contextId}_${AppConstants.contextScheduleOwnSuffix}';

  static String _contextDayOverrideKey(String contextId, DateTime date) => '${AppConstants.contextDayOverridePrefix}_${contextId}_${_dateKey(date)}';

  static String _contextMonthTargetKey(String contextId, int year, int month) => '${AppConstants.contextMonthTargetPrefix}_${contextId}_${_monthKey(year, month)}';

  static String _dateKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String _monthKey(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

  /// Whether [contextId] overrides the global weekly schedule with its own.
  bool getContextUsesOwnSchedule(String contextId) => _box.get(_contextOwnScheduleKey(contextId), defaultValue: false) as bool;

  Future<void> setContextUsesOwnSchedule(String contextId, bool value) => _box.put(_contextOwnScheduleKey(contextId), value);

  /// The context's own schedule for [weekday], regardless of whether it is in
  /// use. Defaults to the global schedule so switching it on starts from what
  /// the user already has.
  WorkDaySchedule getContextOwnDaySchedule(String contextId, int weekday) {
    return WorkDaySchedule(
      start: _box.get(_contextScheduleKey(contextId, weekday, 'start'), defaultValue: getWorkScheduleStart(weekday)) as String,
      end: _box.get(_contextScheduleKey(contextId, weekday, 'end'), defaultValue: getWorkScheduleEnd(weekday)) as String,
      enabled: _box.get(_contextScheduleKey(contextId, weekday, 'enabled'), defaultValue: getWorkScheduleEnabled(weekday)) as bool,
    );
  }

  Future<void> setContextOwnDaySchedule(String contextId, int weekday, WorkDaySchedule schedule) async {
    await _box.put(_contextScheduleKey(contextId, weekday, 'start'), schedule.start);
    await _box.put(_contextScheduleKey(contextId, weekday, 'end'), schedule.end);
    await _box.put(_contextScheduleKey(contextId, weekday, 'enabled'), schedule.enabled);
  }

  /// The schedule that actually applies to [contextId] on [weekday].
  WorkDaySchedule getEffectiveDaySchedule(int weekday, {String? contextId}) {
    if (contextId != null && getContextUsesOwnSchedule(contextId)) {
      return getContextOwnDaySchedule(contextId, weekday);
    }
    return getWorkDaySchedule(weekday);
  }

  Map<String, dynamic> getContextScheduleMap(String contextId) => {for (int day = 1; day <= 7; day++) '$day': getContextOwnDaySchedule(contextId, day).toJson()};

  Future<void> restoreContextScheduleMap(String contextId, Map<dynamic, dynamic> schedule) async {
    for (int day = 1; day <= 7; day++) {
      final raw = schedule['$day'];
      if (raw is Map) await setContextOwnDaySchedule(contextId, day, WorkDaySchedule.fromJson(raw));
    }
  }

  String? getContextDayOverride(String contextId, DateTime date) => _box.get(_contextDayOverrideKey(contextId, date)) as String?;

  Future<void> setContextDayOverride(String contextId, DateTime date, String? type) async {
    final key = _contextDayOverrideKey(contextId, date);
    if (type == null) {
      await _box.delete(key);
    } else {
      await _box.put(key, type);
    }
  }

  Map<DateTime, String> getContextDayOverridesForMonth(String contextId, int year, int month) {
    final result = <DateTime, String>{};
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final override = getContextDayOverride(contextId, date);
      if (override != null) result[date] = override;
    }
    return result;
  }

  /// All context day overrides, keyed `<contextId>|<YYYY-MM-DD>`.
  Map<String, String> getAllContextDayOverrides() {
    final prefix = '${AppConstants.contextDayOverridePrefix}_';
    final result = <String, String>{};
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(prefix)) continue;
      final rest = key.substring(prefix.length);
      final split = rest.lastIndexOf('_');
      if (split <= 0) continue;
      final value = _box.get(key);
      if (value is String) {
        result['${rest.substring(0, split)}${AppConstants.contextKeySeparator}${rest.substring(split + 1)}'] = value;
      }
    }
    return result;
  }

  Future<void> restoreAllContextDayOverrides(Map<String, String> overrides) async {
    final prefix = '${AppConstants.contextDayOverridePrefix}_';
    final keysToDelete = _box.keys.where((k) => k is String && k.startsWith(prefix)).toList();
    for (final key in keysToDelete) {
      await _box.delete(key);
    }
    for (final entry in overrides.entries) {
      final parts = entry.key.split(AppConstants.contextKeySeparator);
      if (parts.length != 2) continue;
      await _box.put('$prefix${parts[0]}_${parts[1]}', entry.value);
    }
  }

  /// Hour goal for one specific month, or null when the context's default applies.
  double? getContextMonthTarget(String contextId, int year, int month) {
    final value = _box.get(_contextMonthTargetKey(contextId, year, month));
    return value is num ? value.toDouble() : null;
  }

  Future<void> setContextMonthTarget(String contextId, int year, int month, double? hours) async {
    final key = _contextMonthTargetKey(contextId, year, month);
    if (hours == null) {
      await _box.delete(key);
    } else {
      await _box.put(key, hours);
    }
  }

  /// Month exceptions of one context, keyed `YYYY-MM`.
  Map<String, double> getContextMonthTargets(String contextId) {
    final prefix = '${AppConstants.contextMonthTargetPrefix}_${contextId}_';
    final result = <String, double>{};
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(prefix)) continue;
      final value = _box.get(key);
      if (value is num) result[key.substring(prefix.length)] = value.toDouble();
    }
    return result;
  }

  Future<void> restoreContextMonthTargets(String contextId, Map<dynamic, dynamic> targets) async {
    final prefix = '${AppConstants.contextMonthTargetPrefix}_${contextId}_';
    final keysToDelete = _box.keys.where((k) => k is String && k.startsWith(prefix)).toList();
    for (final key in keysToDelete) {
      await _box.delete(key);
    }
    for (final entry in targets.entries) {
      final value = entry.value;
      if (value is num) await _box.put('$prefix${entry.key}', value.toDouble());
    }
  }

  /// All month exceptions, keyed `<contextId>|<YYYY-MM>`.
  Map<String, double> getAllContextMonthTargets() {
    final prefix = '${AppConstants.contextMonthTargetPrefix}_';
    final result = <String, double>{};
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(prefix)) continue;
      final rest = key.substring(prefix.length);
      final split = rest.lastIndexOf('_');
      if (split <= 0) continue;
      final value = _box.get(key);
      if (value is num) {
        result['${rest.substring(0, split)}${AppConstants.contextKeySeparator}${rest.substring(split + 1)}'] = value.toDouble();
      }
    }
    return result;
  }

  /// Ids of every context that has any local settings of its own.
  Set<String> getContextIdsWithSettings() {
    final ids = <String>{};
    for (final key in _box.keys) {
      if (key is! String) continue;
      final id = _contextIdOfKey(key);
      if (id != null) ids.add(id);
    }
    return ids;
  }

  /// Extract the context id from one of the `context_*` settings keys, or null
  /// when the key belongs to something else.
  static String? _contextIdOfKey(String key) {
    for (final prefix in [AppConstants.contextDayOverridePrefix, AppConstants.contextMonthTargetPrefix]) {
      if (key.startsWith('${prefix}_')) {
        final rest = key.substring(prefix.length + 1);
        final split = rest.lastIndexOf('_');
        return split > 0 ? rest.substring(0, split) : null;
      }
    }

    if (!key.startsWith('${AppConstants.contextSchedulePrefix}_')) return null;
    var rest = key.substring(AppConstants.contextSchedulePrefix.length + 1);
    if (rest.endsWith('_${AppConstants.contextScheduleOwnSuffix}')) {
      return rest.substring(0, rest.length - AppConstants.contextScheduleOwnSuffix.length - 1);
    }
    // `<id>_<weekday>_<field>`
    final fieldSplit = rest.lastIndexOf('_');
    if (fieldSplit <= 0) return null;
    rest = rest.substring(0, fieldSplit);
    final weekdaySplit = rest.lastIndexOf('_');
    return weekdaySplit > 0 ? rest.substring(0, weekdaySplit) : null;
  }

  /// Remove the settings of every context, leaving global ones intact.
  Future<void> clearAllContextSettings() async {
    final prefixes = ['${AppConstants.contextSchedulePrefix}_', '${AppConstants.contextDayOverridePrefix}_', '${AppConstants.contextMonthTargetPrefix}_'];
    final keysToDelete = _box.keys.where((k) => k is String && prefixes.any(k.startsWith)).toList();
    for (final key in keysToDelete) {
      await _box.delete(key);
    }
  }

  /// The override that applies to [date] for [contextId]: the context's own
  /// override wins, otherwise the global one is inherited.
  String? getEffectiveDayOverride(DateTime date, {String? contextId}) {
    if (contextId != null) {
      final own = getContextDayOverride(contextId, date);
      if (own != null) return own;
    }
    return getDayOverride(date);
  }

  /// Check if a specific date is a work day (considering overrides).
  ///
  /// With [contextId] the context's own schedule and day overrides apply,
  /// falling back to the global ones wherever the context defines nothing.
  bool isWorkDay(DateTime date, {String? contextId}) {
    final override = getEffectiveDayOverride(date, contextId: contextId);
    if (override == 'off') return false;
    if (override == 'work') return true;
    return getEffectiveDaySchedule(date.weekday, contextId: contextId).enabled;
  }

  /// Get expected working hours for a specific date (considering overrides).
  double getExpectedHoursForDate(DateTime date, {String? contextId}) {
    final override = getEffectiveDayOverride(date, contextId: contextId);
    if (override == 'off') return 0;
    final schedule = getEffectiveDaySchedule(date.weekday, contextId: contextId);
    // An extra work day is worth the weekday's hours even though it is disabled.
    if (override == 'work') return schedule.hours;
    return schedule.enabled ? schedule.hours : 0;
  }

  /// Load complete invoice settings from Hive
  InvoiceSettings getInvoiceSettings() {
    final suppliers = getSuppliers();
    final customers = getCustomers();
    final supplierIdx = getSelectedSupplierIndex();
    final customerIdx = getSelectedCustomerIndex();

    final defaultSettings = const InvoiceSettings();

    return InvoiceSettings(
      supplier: (supplierIdx >= 0 && supplierIdx < suppliers.length) ? suppliers[supplierIdx] : defaultSettings.supplier,
      customer: (customerIdx >= 0 && customerIdx < customers.length) ? customers[customerIdx] : defaultSettings.customer,
      description: getInvoiceDescription(),
      bankName: getInvoiceBankName(),
      bankCode: getInvoiceBankCode(),
      swift: getInvoiceSwift(),
      accountNumber: getInvoiceAccountNumber(),
      iban: getInvoiceIban(),
      issuerName: getInvoiceIssuerName(),
      issuerEmail: getInvoiceIssuerEmail(),
      reportFilename: getInvoiceReportFilename(),
      reportRezijniFilename: getInvoiceReportRezijniFilename(),
      invoiceFilename: getInvoiceInvoiceFilename(),
    );
  }
}
