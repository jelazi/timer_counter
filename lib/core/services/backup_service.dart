import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/category_model.dart';
import '../../data/models/invoice_settings.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/running_timer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';

/// Service for full backup and restore of all application data including settings.
class BackupService {
  final TimeEntryRepository _timeEntryRepository;
  final ProjectRepository _projectRepository;
  final TaskRepository _taskRepository;
  final CategoryRepository _categoryRepository;
  final SettingsRepository _settingsRepository;
  final RunningTimerRepository _runningTimerRepository;

  BackupService({
    required TimeEntryRepository timeEntryRepository,
    required ProjectRepository projectRepository,
    required TaskRepository taskRepository,
    required CategoryRepository categoryRepository,
    required SettingsRepository settingsRepository,
    required RunningTimerRepository runningTimerRepository,
  }) : _timeEntryRepository = timeEntryRepository,
       _projectRepository = projectRepository,
       _taskRepository = taskRepository,
       _categoryRepository = categoryRepository,
       _settingsRepository = settingsRepository,
       _runningTimerRepository = runningTimerRepository;

  /// Export a full backup of all application data to JSON.
  /// Includes: categories, projects, tasks, time entries, and all settings.
  Future<String> exportBackup({String? outputPath}) async {
    final categories = _categoryRepository.getAll();
    final projects = _projectRepository.getAll();
    final tasks = _taskRepository.getAll();
    final timeEntries = _timeEntryRepository.getAll();

    final backup = {
      'backup_version': 1,
      'backup_date': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',

      // ── Categories ──
      'categories': categories.map((c) => {'id': c.id, 'name': c.name, 'colorValue': c.colorValue, 'createdAt': c.createdAt.toIso8601String()}).toList(),

      // ── Projects ──
      'projects': projects
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'categoryId': p.categoryId,
              'colorValue': p.colorValue,
              'hourlyRate': p.hourlyRate,
              'plannedTimeHours': p.plannedTimeHours,
              'plannedBudget': p.plannedBudget,
              'startDate': p.startDate?.toIso8601String(),
              'dueDate': p.dueDate?.toIso8601String(),
              'notes': p.notes,
              'isArchived': p.isArchived,
              'isBillable': p.isBillable,
              'createdAt': p.createdAt.toIso8601String(),
            },
          )
          .toList(),

      // ── Tasks ──
      'tasks': tasks
          .map(
            (t) => {
              'id': t.id,
              'projectId': t.projectId,
              'name': t.name,
              'hourlyRate': t.hourlyRate,
              'isBillable': t.isBillable,
              'notes': t.notes,
              'isArchived': t.isArchived,
              'createdAt': t.createdAt.toIso8601String(),
              'colorValue': t.colorValue,
            },
          )
          .toList(),

      // ── Time Entries ──
      'time_entries': timeEntries
          .map(
            (e) => {
              'id': e.id,
              'projectId': e.projectId,
              'taskId': e.taskId,
              'startTime': e.startTime.toIso8601String(),
              'endTime': e.endTime?.toIso8601String(),
              'durationSeconds': e.durationSeconds,
              'notes': e.notes,
              'createdAt': e.createdAt.toIso8601String(),
              'isBillable': e.isBillable,
            },
          )
          .toList(),

      // ── Settings ──
      'settings': _exportSettings(),
    };

    final jsonOutput = const JsonEncoder.withIndent('  ').convert(backup);

    final filePath = outputPath ?? await _getDefaultBackupPath();
    final file = File(filePath);
    await file.writeAsString(jsonOutput);

    return filePath;
  }

  /// Import a full backup from JSON, restoring all data and settings.
  Future<BackupRestoreResult> restoreBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const BackupRestoreResult(error: 'File not found');
      }

      final content = await file.readAsString();
      final jsonData = jsonDecode(content);

      if (jsonData is! Map<String, dynamic>) {
        return const BackupRestoreResult(error: 'Invalid backup format');
      }

      // Check for backup_version key to distinguish from regular export
      if (!jsonData.containsKey('backup_version')) {
        return const BackupRestoreResult(error: 'Not a backup file (missing backup_version)');
      }

      // Clear all existing data
      await _clearAllData();

      int catCount = 0, projCount = 0, taskCount = 0, entryCount = 0;

      // ── Restore Categories ──
      final categories = jsonData['categories'] as List<dynamic>? ?? [];
      for (final c in categories) {
        if (c is! Map<String, dynamic>) continue;
        await _categoryRepository.add(
          CategoryModel(
            id: c['id'] as String? ?? const Uuid().v4(),
            name: c['name'] as String? ?? '',
            colorValue: c['colorValue'] as int? ?? 0xFF6366F1,
            createdAt: DateTime.tryParse(c['createdAt'] as String? ?? '') ?? DateTime.now(),
          ),
        );
        catCount++;
      }

      // ── Restore Projects ──
      final projects = jsonData['projects'] as List<dynamic>? ?? [];
      for (final p in projects) {
        if (p is! Map<String, dynamic>) continue;
        await _projectRepository.add(
          ProjectModel(
            id: p['id'] as String? ?? const Uuid().v4(),
            name: p['name'] as String? ?? '',
            categoryId: p['categoryId'] as String?,
            colorValue: p['colorValue'] as int? ?? 0xFF6366F1,
            hourlyRate: (p['hourlyRate'] as num?)?.toDouble() ?? 0.0,
            plannedTimeHours: (p['plannedTimeHours'] as num?)?.toDouble() ?? 0.0,
            plannedBudget: (p['plannedBudget'] as num?)?.toDouble() ?? 0.0,
            startDate: p['startDate'] != null ? DateTime.tryParse(p['startDate'] as String) : null,
            dueDate: p['dueDate'] != null ? DateTime.tryParse(p['dueDate'] as String) : null,
            notes: p['notes'] as String? ?? '',
            isArchived: p['isArchived'] as bool? ?? false,
            isBillable: p['isBillable'] as bool? ?? true,
            createdAt: DateTime.tryParse(p['createdAt'] as String? ?? '') ?? DateTime.now(),
          ),
        );
        projCount++;
      }

      // ── Restore Tasks ──
      final tasks = jsonData['tasks'] as List<dynamic>? ?? [];
      for (final t in tasks) {
        if (t is! Map<String, dynamic>) continue;
        await _taskRepository.add(
          TaskModel(
            id: t['id'] as String? ?? const Uuid().v4(),
            projectId: t['projectId'] as String? ?? '',
            name: t['name'] as String? ?? '',
            hourlyRate: (t['hourlyRate'] as num?)?.toDouble(),
            isBillable: t['isBillable'] as bool? ?? true,
            notes: t['notes'] as String? ?? '',
            isArchived: t['isArchived'] as bool? ?? false,
            createdAt: DateTime.tryParse(t['createdAt'] as String? ?? '') ?? DateTime.now(),
            colorValue: t['colorValue'] as int? ?? 0xFF6366F1,
          ),
        );
        taskCount++;
      }

      // ── Restore Time Entries ──
      final entries = jsonData['time_entries'] as List<dynamic>? ?? [];
      for (final e in entries) {
        if (e is! Map<String, dynamic>) continue;
        await _timeEntryRepository.add(
          TimeEntryModel(
            id: e['id'] as String? ?? const Uuid().v4(),
            projectId: e['projectId'] as String? ?? '',
            taskId: e['taskId'] as String? ?? '',
            startTime: DateTime.tryParse(e['startTime'] as String? ?? '') ?? DateTime.now(),
            endTime: e['endTime'] != null ? DateTime.tryParse(e['endTime'] as String) : null,
            durationSeconds: e['durationSeconds'] as int? ?? 0,
            notes: e['notes'] as String? ?? '',
            createdAt: DateTime.tryParse(e['createdAt'] as String? ?? '') ?? DateTime.now(),
            isBillable: e['isBillable'] as bool? ?? true,
          ),
        );
        entryCount++;
      }

      // ── Restore Settings ──
      final settings = jsonData['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        await _restoreSettings(settings);
      }

      return BackupRestoreResult(
        categoriesRestored: catCount,
        projectsRestored: projCount,
        tasksRestored: taskCount,
        entriesRestored: entryCount,
        settingsRestored: settings != null,
      );
    } catch (e) {
      debugPrint('Backup restore error: $e');
      return BackupRestoreResult(error: e.toString());
    }
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
    // Stop running timers
    await _runningTimerRepository.stopAll();

    // Clear in reverse dependency order
    final allEntries = _timeEntryRepository.getAll();
    for (final entry in allEntries) {
      await _timeEntryRepository.delete(entry.id);
    }
    final allTasks = _taskRepository.getAll();
    for (final task in allTasks) {
      await _taskRepository.delete(task.id);
    }
    final allProjects = _projectRepository.getAll();
    for (final project in allProjects) {
      await _projectRepository.delete(project.id);
    }
    final allCategories = _categoryRepository.getAll();
    for (final category in allCategories) {
      await _categoryRepository.delete(category.id);
    }
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
  final bool settingsRestored;
  final String? error;

  const BackupRestoreResult({this.categoriesRestored = 0, this.projectsRestored = 0, this.tasksRestored = 0, this.entriesRestored = 0, this.settingsRestored = false, this.error});

  bool get hasError => error != null;

  int get total => categoriesRestored + projectsRestored + tasksRestored + entriesRestored;
}
