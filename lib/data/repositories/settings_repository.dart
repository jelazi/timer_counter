import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../models/invoice_settings.dart';

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
  String getInvoiceDescription() => _box.get(AppConstants.invoiceDescription, defaultValue: 'Vývoj aplikace Artemis') as String;
  Future<void> setInvoiceDescription(String desc) => _box.put(AppConstants.invoiceDescription, desc);

  // Bank info
  String getInvoiceBankName() => _box.get(AppConstants.invoiceBankName, defaultValue: '') as String;
  Future<void> setInvoiceBankName(String v) => _box.put(AppConstants.invoiceBankName, v);

  String getInvoiceBankCode() => _box.get(AppConstants.invoiceBankCode, defaultValue: '6210') as String;
  Future<void> setInvoiceBankCode(String v) => _box.put(AppConstants.invoiceBankCode, v);

  String getInvoiceSwift() => _box.get(AppConstants.invoiceSwift, defaultValue: '') as String;
  Future<void> setInvoiceSwift(String v) => _box.put(AppConstants.invoiceSwift, v);

  String getInvoiceAccountNumber() => _box.get(AppConstants.invoiceAccountNumber, defaultValue: '670100-2200840281') as String;
  Future<void> setInvoiceAccountNumber(String v) => _box.put(AppConstants.invoiceAccountNumber, v);

  String getInvoiceIban() => _box.get(AppConstants.invoiceIban, defaultValue: 'CZ2862106701002200840281') as String;
  Future<void> setInvoiceIban(String v) => _box.put(AppConstants.invoiceIban, v);

  // Issuer
  String getInvoiceIssuerName() => _box.get(AppConstants.invoiceIssuerName, defaultValue: 'Lubomír Žižka') as String;
  Future<void> setInvoiceIssuerName(String v) => _box.put(AppConstants.invoiceIssuerName, v);

  String getInvoiceIssuerEmail() => _box.get(AppConstants.invoiceIssuerEmail, defaultValue: 'lzizka@gmail.com') as String;
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

  /// Get today's expected working hours (0 if not a work day)
  double getTodayExpectedHours() {
    final weekday = DateTime.now().weekday; // 1=Monday
    if (!getWorkScheduleEnabled(weekday)) return 0;
    final start = getWorkScheduleStart(weekday);
    final end = getWorkScheduleEnd(weekday);
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    return (endMinutes - startMinutes) / 60.0;
  }

  /// Get expected working hours for a specific weekday
  double getExpectedHoursForDay(int weekday) {
    if (!getWorkScheduleEnabled(weekday)) return 0;
    final start = getWorkScheduleStart(weekday);
    final end = getWorkScheduleEnd(weekday);
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    return (endMinutes - startMinutes) / 60.0;
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
