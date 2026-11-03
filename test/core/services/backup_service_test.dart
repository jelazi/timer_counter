import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:timer_counter/core/services/backup_service.dart';
import 'package:timer_counter/data/models/work_day_schedule.dart';
import 'package:timer_counter/data/repositories/category_repository.dart';
import 'package:timer_counter/data/repositories/monthly_hours_target_repository.dart';
import 'package:timer_counter/data/repositories/project_repository.dart';
import 'package:timer_counter/data/repositories/running_timer_repository.dart';
import 'package:timer_counter/data/repositories/settings_repository.dart';
import 'package:timer_counter/data/repositories/standalone_invoice_repository.dart';
import 'package:timer_counter/data/repositories/task_repository.dart';
import 'package:timer_counter/data/repositories/time_entry_repository.dart';

void main() {
  late Directory tempDir;
  late SettingsRepository settings;
  late BackupService backup;

  const contextId = 'ctx-medutech';
  const ownMonday = WorkDaySchedule(start: '07:00', end: '12:00', enabled: true);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('timer_counter_backup_test');
    Hive.init(tempDir.path);

    settings = SettingsRepository();
    final timeEntries = TimeEntryRepository();
    final projects = ProjectRepository();
    final tasks = TaskRepository();
    final categories = CategoryRepository();
    final runningTimers = RunningTimerRepository();
    final monthlyTargets = MonthlyHoursTargetRepository();
    final invoices = StandaloneInvoiceRepository();
    for (final init in [settings.init, timeEntries.init, projects.init, tasks.init, categories.init, runningTimers.init, monthlyTargets.init, invoices.init]) {
      await init();
    }

    backup = BackupService(
      timeEntryRepository: timeEntries,
      projectRepository: projects,
      taskRepository: tasks,
      categoryRepository: categories,
      settingsRepository: settings,
      runningTimerRepository: runningTimers,
      monthlyTargetRepository: monthlyTargets,
      standaloneInvoiceRepository: invoices,
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> seedContextSettings() async {
    await settings.setContextUsesOwnSchedule(contextId, true);
    await settings.setContextOwnDaySchedule(contextId, DateTime.monday, ownMonday);
    await settings.setContextMonthTarget(contextId, 2026, 11, 120);
    await settings.setContextDayOverride(contextId, DateTime(2026, 11, 17), 'off');
  }

  void expectContextSettingsSeeded() {
    expect(settings.getContextUsesOwnSchedule(contextId), isTrue);
    expect(settings.getContextOwnDaySchedule(contextId, DateTime.monday), ownMonday);
    expect(settings.getContextMonthTarget(contextId, 2026, 11), 120);
    expect(settings.getContextDayOverride(contextId, DateTime(2026, 11, 17)), 'off');
  }

  Future<String> writeFile(Map<String, dynamic> json) async {
    final file = File('${tempDir.path}/backup.json');
    await file.writeAsString(jsonEncode(json));
    return file.path;
  }

  test('a v3 backup restores the work schedule and every context setting', () async {
    await settings.setWorkDaySchedule(DateTime.friday, const WorkDaySchedule(start: '08:00', end: '13:00', enabled: true));
    await seedContextSettings();
    final path = await backup.exportBackup(outputPath: '${tempDir.path}/v3.json');

    await settings.clearAllContextSettings();
    await settings.setWorkDaySchedule(DateTime.friday, const WorkDaySchedule(start: '09:00', end: '17:00', enabled: false));

    final result = await backup.restoreBackup(path);

    expect(result.hasError, isFalse);
    expect(settings.getWorkDaySchedule(DateTime.friday), const WorkDaySchedule(start: '08:00', end: '13:00', enabled: true));
    expectContextSettingsSeeded();
  });

  test('restoring a v2 backup keeps the context settings it does not know about', () async {
    await seedContextSettings();
    final path = await writeFile({
      'backup_version': 2,
      'categories': <dynamic>[],
      'projects': <dynamic>[],
      'tasks': <dynamic>[],
      'time_entries': <dynamic>[],
      'monthly_targets': <dynamic>[],
      'standalone_invoices': <dynamic>[],
      'settings': {'themeMode': 'dark', 'dailyWorkingHours': 6},
    });

    final result = await backup.restoreBackup(path);

    expect(result.hasError, isFalse);
    expect(settings.getThemeMode(), 'dark');
    expectContextSettingsSeeded();
  });

  test('deleting data and settings does wipe the context settings', () async {
    await seedContextSettings();

    await backup.deleteAllDataAndSettings();

    expect(settings.getContextIdsWithSettings(), isEmpty);
  });

  test('a file without backup_version is refused and nothing is cleared', () async {
    await seedContextSettings();
    final path = await writeFile({'time_entries': <dynamic>[]});

    final result = await backup.restoreBackup(path);

    expect(result.hasError, isTrue);
    expectContextSettingsSeeded();
  });
}
