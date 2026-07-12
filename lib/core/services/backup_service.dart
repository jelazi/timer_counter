import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/category_model.dart';
import '../../data/models/invoice_settings.dart';
import '../../data/models/monthly_hours_target_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/standalone_invoice_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/monthly_hours_target_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/running_timer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/standalone_invoice_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';

/// Service for full backup and restore of all application data including settings.
class BackupService {
  /// Bumped to 2 when monthly targets and standalone invoices were added to the
  /// payload. Version 1 files restore fine — their missing keys read as empty.
  static const int backupVersion = 2;

  final TimeEntryRepository _timeEntryRepository;
  final ProjectRepository _projectRepository;
  final TaskRepository _taskRepository;
  final CategoryRepository _categoryRepository;
  final SettingsRepository _settingsRepository;
  final RunningTimerRepository _runningTimerRepository;
  final MonthlyHoursTargetRepository _monthlyTargetRepository;
  final StandaloneInvoiceRepository _standaloneInvoiceRepository;

  BackupService({
    required TimeEntryRepository timeEntryRepository,
    required ProjectRepository projectRepository,
    required TaskRepository taskRepository,
    required CategoryRepository categoryRepository,
    required SettingsRepository settingsRepository,
    required RunningTimerRepository runningTimerRepository,
    required MonthlyHoursTargetRepository monthlyTargetRepository,
    required StandaloneInvoiceRepository standaloneInvoiceRepository,
  }) : _timeEntryRepository = timeEntryRepository,
       _projectRepository = projectRepository,
       _taskRepository = taskRepository,
       _categoryRepository = categoryRepository,
       _settingsRepository = settingsRepository,
       _runningTimerRepository = runningTimerRepository,
       _monthlyTargetRepository = monthlyTargetRepository,
       _standaloneInvoiceRepository = standaloneInvoiceRepository;

  /// Serialize the complete local dataset.
  ///
  /// Shared by the manual export and the automatic daily snapshots, so both
  /// always capture exactly the same thing.
  Map<String, dynamic> buildBackupMap() {
    return {
      'backup_version': backupVersion,
      'backup_date': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      // Which PocketBase account this data belongs to. A snapshot taken under
      // one account must not be restored into (and pushed to) another.
      'owner_id': _settingsRepository.getPocketBaseOwnerId(),
      'categories': _categoryRepository.getAll().map((c) => c.toJson()).toList(),
      'projects': _projectRepository.getAll().map((p) => p.toJson()).toList(),
      'tasks': _taskRepository.getAll().map((t) => t.toJson()).toList(),
      'time_entries': _timeEntryRepository.getAll().map((e) => e.toJson()).toList(),
      'monthly_targets': _monthlyTargetRepository.getAll().map((m) => m.toJson()).toList(),
      'standalone_invoices': _standaloneInvoiceRepository.getAll().map((i) => i.toJson()).toList(),
      'settings': _exportSettings(),
    };
  }

  /// Export a full backup of all application data to JSON.
  Future<String> exportBackup({String? outputPath}) async {
    final jsonOutput = const JsonEncoder.withIndent('  ').convert(buildBackupMap());

    final filePath = outputPath ?? await _getDefaultBackupPath();
    await File(filePath).writeAsString(jsonOutput);

    return filePath;
  }

  /// Import a full backup from JSON, restoring all data and settings.
  Future<BackupRestoreResult> restoreBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const BackupRestoreResult(error: 'File not found');
      }

      final jsonData = jsonDecode(await file.readAsString());

      if (jsonData is! Map<String, dynamic>) {
        return const BackupRestoreResult(error: 'Invalid backup format');
      }

      // Distinguishes a backup from a plain data export.
      if (!jsonData.containsKey('backup_version')) {
        return const BackupRestoreResult(error: 'Not a backup file (missing backup_version)');
      }

      await _clearAllData();

      final result = await applyBackupMap(jsonData);
      return result;
    } catch (e) {
      debugPrint('Backup restore error: $e');
      return BackupRestoreResult(error: e.toString());
    }
  }

  /// Write the contents of a backup/snapshot map into the repositories.
  ///
  /// Does NOT clear existing data first — callers decide whether this is a
  /// wholesale restore or a merge (as the snapshot recovery flow needs).
  Future<BackupRestoreResult> applyBackupMap(Map<String, dynamic> jsonData) async {
    int catCount = 0, projCount = 0, taskCount = 0, entryCount = 0, targetCount = 0, invoiceCount = 0;

    for (final c in _mapsIn(jsonData['categories'])) {
      await _categoryRepository.add(CategoryModel.fromJson(c));
      catCount++;
    }
    for (final p in _mapsIn(jsonData['projects'])) {
      await _projectRepository.add(ProjectModel.fromJson(p));
      projCount++;
    }
    for (final t in _mapsIn(jsonData['tasks'])) {
      await _taskRepository.add(TaskModel.fromJson(t));
      taskCount++;
    }
    for (final e in _mapsIn(jsonData['time_entries'])) {
      await _timeEntryRepository.add(TimeEntryModel.fromJson(e));
      entryCount++;
    }
    // Absent in version 1 backups.
    for (final m in _mapsIn(jsonData['monthly_targets'])) {
      await _monthlyTargetRepository.add(MonthlyHoursTargetModel.fromJson(m));
      targetCount++;
    }
    for (final i in _mapsIn(jsonData['standalone_invoices'])) {
      await _standaloneInvoiceRepository.add(StandaloneInvoiceModel.fromJson(i));
      invoiceCount++;
    }

    final settings = jsonData['settings'] as Map<String, dynamic>?;
    if (settings != null) {
      await _restoreSettings(settings);
    }

    return BackupRestoreResult(
      categoriesRestored: catCount,
      projectsRestored: projCount,
      tasksRestored: taskCount,
      entriesRestored: entryCount,
      targetsRestored: targetCount,
      invoicesRestored: invoiceCount,
      settingsRestored: settings != null,
    );
  }

  /// Delete all application data (categories, projects, tasks, time entries, running timers).
  /// Does NOT delete settings.
  Future<void> deleteAllData() async {
    await _clearAllData();
  }

  /// Delete everything including settings.
  Future<void> deleteAllDataAndSettings() async {
    await _clearAllData();
    await _clearSettings();
  }

  // ─────────────────────────────────────────────────────────────────────────

  Iterable<Map<String, dynamic>> _mapsIn(dynamic value) sync* {
    if (value is! List) return;
    for (final item in value) {
      if (item is Map) yield item.cast<String, dynamic>();
    }
  }

  Map<String, dynamic> _exportSettings() {
    return {
      // Appearance
      'themeMode': _settingsRepository.getThemeMode(),
      'language': _settingsRepository.getLanguage(),

      // Timer
      'simultaneousTimers': _settingsRepository.getSimultaneousTimers(),
      'showSeconds': _settingsRepository.getShowSeconds(),
      'roundTime': _settingsRepository.getRoundTime(),
      'roundToMinutes': _settingsRepository.getRoundToMinutes(),

      // Working hours
      'dailyWorkingHours': _settingsRepository.getDailyWorkingHours(),
      'weeklyWorkingDays': _settingsRepository.getWeeklyWorkingDays(),

      // General
      'timeFormat': _settingsRepository.getTimeFormat(),
      'currency': _settingsRepository.getCurrency(),

      // System
      'launchAtStartup': _settingsRepository.getLaunchAtStartup(),
      'minimizeToTray': _settingsRepository.getMinimizeToTray(),
      'allowOverlapTimes': _settingsRepository.getAllowOverlapTimes(),

      // Reminders
      'remindStart': _settingsRepository.getRemindStart(),
      'remindStop': _settingsRepository.getRemindStop(),
      'remindBreak': _settingsRepository.getRemindBreak(),

      // Invoice settings
      'invoiceDescription': _settingsRepository.getInvoiceDescription(),
      'invoiceBankName': _settingsRepository.getInvoiceBankName(),
      'invoiceBankCode': _settingsRepository.getInvoiceBankCode(),
      'invoiceSwift': _settingsRepository.getInvoiceSwift(),
      'invoiceAccountNumber': _settingsRepository.getInvoiceAccountNumber(),
      'invoiceIban': _settingsRepository.getInvoiceIban(),
      'invoiceIssuerName': _settingsRepository.getInvoiceIssuerName(),
      'invoiceIssuerEmail': _settingsRepository.getInvoiceIssuerEmail(),
      'invoiceReportFilename': _settingsRepository.getInvoiceReportFilename(),
      'invoiceReportRezijniFilename': _settingsRepository.getInvoiceReportRezijniFilename(),
      'invoiceInvoiceFilename': _settingsRepository.getInvoiceInvoiceFilename(),
      'invoiceSelectedSupplierIndex': _settingsRepository.getSelectedSupplierIndex(),
      'invoiceSelectedCustomerIndex': _settingsRepository.getSelectedCustomerIndex(),

      // Suppliers & Customers (as JSON-serializable lists)
      'invoiceSuppliers': _settingsRepository.getSuppliers().map((s) => s.toJson()).toList(),
      'invoiceCustomers': _settingsRepository.getCustomers().map((c) => c.toJson()).toList(),

      // PocketBase
      'pocketBaseUrl': _settingsRepository.getPocketBaseUrl(),
      'pocketBaseEmail': _settingsRepository.getPocketBaseEmail(),
      'pocketBasePassword': _settingsRepository.getPocketBasePassword(),
      'pocketBaseEnabled': _settingsRepository.getPocketBaseEnabled(),
      'pocketBaseLastSync': _settingsRepository.getPocketBaseLastSync(),

      // Day overrides
      'dayOverrides': _settingsRepository.getAllDayOverrides(),
    };
  }

  Future<void> _restoreSettings(Map<String, dynamic> s) async {
    // Appearance
    if (s['themeMode'] != null) await _settingsRepository.setThemeMode(s['themeMode'] as String);
    if (s['language'] != null) await _settingsRepository.setLanguage(s['language'] as String);

    // Timer
    if (s['simultaneousTimers'] != null) await _settingsRepository.setSimultaneousTimers(s['simultaneousTimers'] as bool);
    if (s['showSeconds'] != null) await _settingsRepository.setShowSeconds(s['showSeconds'] as bool);
    if (s['roundTime'] != null) await _settingsRepository.setRoundTime(s['roundTime'] as bool);
    if (s['roundToMinutes'] != null) await _settingsRepository.setRoundToMinutes(s['roundToMinutes'] as int);

    // Working hours
    if (s['dailyWorkingHours'] != null) await _settingsRepository.setDailyWorkingHours((s['dailyWorkingHours'] as num).toDouble());
    if (s['weeklyWorkingDays'] != null) await _settingsRepository.setWeeklyWorkingDays(s['weeklyWorkingDays'] as int);

    // General
    if (s['timeFormat'] != null) await _settingsRepository.setTimeFormat(s['timeFormat'] as String);
    if (s['currency'] != null) await _settingsRepository.setCurrency(s['currency'] as String);

    // System
    if (s['launchAtStartup'] != null) await _settingsRepository.setLaunchAtStartup(s['launchAtStartup'] as bool);
    if (s['minimizeToTray'] != null) await _settingsRepository.setMinimizeToTray(s['minimizeToTray'] as bool);
    if (s['allowOverlapTimes'] != null) await _settingsRepository.setAllowOverlapTimes(s['allowOverlapTimes'] as bool);

    // Reminders
    if (s['remindStart'] != null) await _settingsRepository.setRemindStart(s['remindStart'] as bool);
    if (s['remindStop'] != null) await _settingsRepository.setRemindStop(s['remindStop'] as bool);
    if (s['remindBreak'] != null) await _settingsRepository.setRemindBreak(s['remindBreak'] as bool);

    // Invoice settings
    if (s['invoiceDescription'] != null) await _settingsRepository.setInvoiceDescription(s['invoiceDescription'] as String);
    if (s['invoiceBankName'] != null) await _settingsRepository.setInvoiceBankName(s['invoiceBankName'] as String);
    if (s['invoiceBankCode'] != null) await _settingsRepository.setInvoiceBankCode(s['invoiceBankCode'] as String);
    if (s['invoiceSwift'] != null) await _settingsRepository.setInvoiceSwift(s['invoiceSwift'] as String);
    if (s['invoiceAccountNumber'] != null) await _settingsRepository.setInvoiceAccountNumber(s['invoiceAccountNumber'] as String);
    if (s['invoiceIban'] != null) await _settingsRepository.setInvoiceIban(s['invoiceIban'] as String);
    if (s['invoiceIssuerName'] != null) await _settingsRepository.setInvoiceIssuerName(s['invoiceIssuerName'] as String);
    if (s['invoiceIssuerEmail'] != null) await _settingsRepository.setInvoiceIssuerEmail(s['invoiceIssuerEmail'] as String);
    if (s['invoiceReportFilename'] != null) await _settingsRepository.setInvoiceReportFilename(s['invoiceReportFilename'] as String);
    if (s['invoiceReportRezijniFilename'] != null) await _settingsRepository.setInvoiceReportRezijniFilename(s['invoiceReportRezijniFilename'] as String);
    if (s['invoiceInvoiceFilename'] != null) await _settingsRepository.setInvoiceInvoiceFilename(s['invoiceInvoiceFilename'] as String);
    if (s['invoiceSelectedSupplierIndex'] != null) await _settingsRepository.setSelectedSupplierIndex(s['invoiceSelectedSupplierIndex'] as int);
    if (s['invoiceSelectedCustomerIndex'] != null) await _settingsRepository.setSelectedCustomerIndex(s['invoiceSelectedCustomerIndex'] as int);

    // Suppliers & Customers
    if (s['invoiceSuppliers'] != null) {
      final suppliers = (s['invoiceSuppliers'] as List<dynamic>).map((e) => InvoiceParty.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      await _settingsRepository.setSuppliers(suppliers);
    }
    if (s['invoiceCustomers'] != null) {
      final customers = (s['invoiceCustomers'] as List<dynamic>).map((e) => InvoiceParty.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      await _settingsRepository.setCustomers(customers);
    }

    // PocketBase
    if (s['pocketBaseUrl'] != null) await _settingsRepository.setPocketBaseUrl(s['pocketBaseUrl'] as String);
    if (s['pocketBaseEmail'] != null) await _settingsRepository.setPocketBaseEmail(s['pocketBaseEmail'] as String);
    if (s['pocketBasePassword'] != null) await _settingsRepository.setPocketBasePassword(s['pocketBasePassword'] as String);
    if (s['pocketBaseEnabled'] != null) await _settingsRepository.setPocketBaseEnabled(s['pocketBaseEnabled'] as bool);
    if (s['pocketBaseLastSync'] != null) await _settingsRepository.setPocketBaseLastSync(s['pocketBaseLastSync'] as String);

    // Day overrides
    if (s['dayOverrides'] != null) {
      final overrides = (s['dayOverrides'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
      await _settingsRepository.restoreAllDayOverrides(overrides);
    }
  }

  Future<void> _clearAllData() async {
    await _runningTimerRepository.stopAll();

    // `deleteAll` journals every record as a bulk clear, so a restore that turns
    // out to be the wrong file can still be undone from the deletion journal.
    await _timeEntryRepository.deleteAll();
    await _taskRepository.deleteAll();
    await _projectRepository.deleteAll();
    await _categoryRepository.deleteAll();
    await _monthlyTargetRepository.deleteAll();
    await _standaloneInvoiceRepository.deleteAll();
  }

  Future<void> _clearSettings() async {
    // Reset settings to defaults
    await _settingsRepository.setThemeMode('system');
    await _settingsRepository.setLanguage('en');
    await _settingsRepository.setSimultaneousTimers(false);
    await _settingsRepository.setShowSeconds(true);
    await _settingsRepository.setRoundTime(false);
    await _settingsRepository.setRoundToMinutes(5);
    await _settingsRepository.setDailyWorkingHours(8.0);
    await _settingsRepository.setWeeklyWorkingDays(5);
    await _settingsRepository.setTimeFormat('hm');
    await _settingsRepository.setCurrency('CZK');
    await _settingsRepository.setLaunchAtStartup(false);
    await _settingsRepository.setMinimizeToTray(true);
    await _settingsRepository.setAllowOverlapTimes(false);
    await _settingsRepository.setRemindStart(false);
    await _settingsRepository.setRemindStop(false);
    await _settingsRepository.setRemindBreak(false);
    await _settingsRepository.setPocketBaseUrl('');
    await _settingsRepository.setPocketBaseEmail('');
    await _settingsRepository.setPocketBasePassword('');
    await _settingsRepository.setPocketBaseEnabled(false);
    await _settingsRepository.setPocketBaseLastSync('');
  }

  Future<String> _getDefaultBackupPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    return '${dir.path}/timer_counter_backup_$timestamp.json';
  }
}

class BackupRestoreResult {
  final int categoriesRestored;
  final int projectsRestored;
  final int tasksRestored;
  final int entriesRestored;
  final int targetsRestored;
  final int invoicesRestored;
  final bool settingsRestored;
  final String? error;

  const BackupRestoreResult({
    this.categoriesRestored = 0,
    this.projectsRestored = 0,
    this.tasksRestored = 0,
    this.entriesRestored = 0,
    this.targetsRestored = 0,
    this.invoicesRestored = 0,
    this.settingsRestored = false,
    this.error,
  });

  bool get hasError => error != null;

  int get total => categoriesRestored + projectsRestored + tasksRestored + entriesRestored + targetsRestored + invoicesRestored;
}
