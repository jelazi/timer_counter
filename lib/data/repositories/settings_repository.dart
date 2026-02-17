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
