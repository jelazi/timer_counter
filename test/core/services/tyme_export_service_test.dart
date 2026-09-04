import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timer_counter/core/services/tyme_export_service.dart';
import 'package:timer_counter/data/models/category_model.dart';
import 'package:timer_counter/data/models/project_model.dart';
import 'package:timer_counter/data/models/task_model.dart';
import 'package:timer_counter/data/models/time_entry_model.dart';
import 'package:timer_counter/data/repositories/category_repository.dart';
import 'package:timer_counter/data/repositories/project_repository.dart';
import 'package:timer_counter/data/repositories/settings_repository.dart';
import 'package:timer_counter/data/repositories/task_repository.dart';
import 'package:timer_counter/data/repositories/time_entry_repository.dart';

class MockTimeEntryRepository extends Mock implements TimeEntryRepository {}

class MockProjectRepository extends Mock implements ProjectRepository {}

class MockTaskRepository extends Mock implements TaskRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

TimeEntryModel _entry({
  String id = 'e1',
  DateTime? start,
  int seconds = 3600,
  String projectId = 'p1',
  String taskId = 't1',
  bool isBillable = true,
  String notes = '',
}) {
  final startTime = start ?? DateTime(2026, 3, 2, 9);
  return TimeEntryModel(
    id: id,
    projectId: projectId,
    taskId: taskId,
    startTime: startTime,
    endTime: startTime.add(Duration(seconds: seconds)),
    notes: notes,
    isBillable: isBillable,
    createdAt: startTime,
  );
}

void main() {
  late MockTimeEntryRepository timeEntries;
  late MockProjectRepository projects;
  late MockTaskRepository tasks;
  late MockCategoryRepository categories;
  late MockSettingsRepository settings;
  late TymeExportService service;
  late Directory tempDir;

  setUp(() async {
    timeEntries = MockTimeEntryRepository();
    projects = MockProjectRepository();
    tasks = MockTaskRepository();
    categories = MockCategoryRepository();
    settings = MockSettingsRepository();

    when(() => settings.getCurrency()).thenReturn('CZK');
    when(() => settings.getRoundTime()).thenReturn(false);
    when(() => settings.getRoundToMinutes()).thenReturn(1);
    when(() => projects.getById(any())).thenReturn(null);
    when(() => tasks.getById(any())).thenReturn(null);
    when(() => categories.getById(any())).thenReturn(null);

    service = TymeExportService(
      timeEntryRepository: timeEntries,
      projectRepository: projects,
      taskRepository: tasks,
      categoryRepository: categories,
      settingsRepository: settings,
    );

    tempDir = await Directory.systemTemp.createTemp('tyme_export_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<List<Map<String, dynamic>>> exportEntries(
    List<TimeEntryModel> entries, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    when(() => timeEntries.getAll()).thenReturn(entries);
    when(() => timeEntries.getByDateRange(any(), any())).thenReturn(entries);

    final path = '${tempDir.path}/export.json';
    await service.exportToJson(outputPath: path, startDate: startDate, endDate: endDate);
    final decoded = json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
    return (decoded['data'] as List).cast<Map<String, dynamic>>();
  }

  group('duration rounding', () {
    test('reports whole minutes when rounding is disabled', () async {
      final data = await exportEntries([_entry(seconds: 25 * 60)]);

      expect(data.single['duration'], 25);
    });

    test('rounds to the nearest configured step', () async {
      when(() => settings.getRoundTime()).thenReturn(true);
      when(() => settings.getRoundToMinutes()).thenReturn(15);

      final data = await exportEntries([
        _entry(id: 'up', seconds: 23 * 60),
        _entry(id: 'down', seconds: 8 * 60),
      ]);

      expect(data.firstWhere((e) => e['id'] == 'up')['duration'], 30);
      expect(data.firstWhere((e) => e['id'] == 'down')['duration'], 15);
    });

    test('collapses an entry shorter than half a step to the one-minute floor', () async {
      when(() => settings.getRoundTime()).thenReturn(true);
      when(() => settings.getRoundToMinutes()).thenReturn(15);

      final data = await exportEntries([_entry(seconds: 7 * 60)]);

      expect(data.single['duration'], 1);
    });

    test('never exports a zero duration', () async {
      final data = await exportEntries([_entry(seconds: 10)]);

      expect(data.single['duration'], 1);
    });
  });

  group('hourly rate resolution', () {
    test('a task rate overrides the project rate', () async {
      when(() => projects.getById('p1')).thenReturn(
        ProjectModel(id: 'p1', name: 'Project', colorValue: 0, hourlyRate: 500, createdAt: DateTime(2026)),
      );
      when(() => tasks.getById('t1')).thenReturn(
        TaskModel(id: 't1', projectId: 'p1', name: 'Task', hourlyRate: 800, createdAt: DateTime(2026)),
      );

      final data = await exportEntries([_entry(seconds: 3600)]);

      expect(data.single['rate'], 800);
      expect(data.single['sum'], 800);
    });

    test('falls back to the project rate when the task rate is zero', () async {
      when(() => projects.getById('p1')).thenReturn(
        ProjectModel(id: 'p1', name: 'Project', colorValue: 0, hourlyRate: 500, createdAt: DateTime(2026)),
      );
      when(() => tasks.getById('t1')).thenReturn(
        TaskModel(id: 't1', projectId: 'p1', name: 'Task', hourlyRate: 0, createdAt: DateTime(2026)),
      );

      final data = await exportEntries([_entry(seconds: 3600)]);

      expect(data.single['rate'], 500);
    });

    test('exports a zero rate when neither project nor task is known', () async {
      final data = await exportEntries([_entry(seconds: 3600)]);

      expect(data.single['rate'], 0.0);
      expect(data.single['sum'], 0.0);
    });

    test('bills a half hour at half the hourly rate', () async {
      when(() => projects.getById('p1')).thenReturn(
        ProjectModel(id: 'p1', name: 'Project', colorValue: 0, hourlyRate: 550, createdAt: DateTime(2026)),
      );

      final data = await exportEntries([_entry(seconds: 1800)]);

      expect(data.single['sum'], 275);
    });
  });

  group('entry payload', () {
    test('resolves the category through the project', () async {
      when(() => projects.getById('p1')).thenReturn(
        ProjectModel(id: 'p1', name: 'Project', categoryId: 'c1', colorValue: 0, createdAt: DateTime(2026)),
      );
      when(() => categories.getById('c1')).thenReturn(
        CategoryModel(id: 'c1', name: 'Category', colorValue: 0, createdAt: DateTime(2026)),
      );

      final data = await exportEntries([_entry()]);

      expect(data.single['category'], 'Category');
      expect(data.single['category_id'], 'c1');
    });

    test('leaves the category blank when the project has none', () async {
      when(() => projects.getById('p1')).thenReturn(
        ProjectModel(id: 'p1', name: 'Project', colorValue: 0, createdAt: DateTime(2026)),
      );

      final data = await exportEntries([_entry()]);

      expect(data.single['category'], '');
      expect(data.single['category_id'], '');
    });

    test('maps the billable flag onto Tyme billing states', () async {
      final data = await exportEntries([
        _entry(id: 'billable'),
        _entry(id: 'internal', isBillable: false),
      ]);

      expect(data.firstWhere((e) => e['id'] == 'billable')['billing'], 'UNBILLED');
      expect(data.firstWhere((e) => e['id'] == 'internal')['billing'], 'NON_BILLABLE');
    });

    test('formats the date as a day with a timezone offset and no clock time', () async {
      final data = await exportEntries([_entry(start: DateTime(2026, 3, 2, 14, 37))]);

      expect(data.single['date'], startsWith('2026-03-02T00:00:00'));
      expect(data.single['date'], matches(RegExp(r'[+-]\d{2}:\d{2}$')));
    });

    test('keeps the wall-clock times of the entry itself', () async {
      final data = await exportEntries([_entry(start: DateTime(2026, 3, 2, 14, 37), seconds: 3600)]);

      expect(data.single['start_time'], '14:37');
      expect(data.single['stop_time'], '15:37');
    });

    test('carries the configured currency into both amount fields', () async {
      when(() => settings.getCurrency()).thenReturn('EUR');

      final data = await exportEntries([_entry()]);

      expect(data.single['rate_unit'], 'EUR');
      expect(data.single['sum_unit'], 'EUR');
    });
  });

  group('entry selection', () {
    test('exports every entry when no range is given', () async {
      await exportEntries([_entry(id: 'a'), _entry(id: 'b')]);

      verify(() => timeEntries.getAll()).called(1);
      verifyNever(() => timeEntries.getByDateRange(any(), any()));
    });

    test('queries by range when both bounds are given', () async {
      final from = DateTime(2026, 3);
      final to = DateTime(2026, 3, 31);

      await exportEntries([_entry()], startDate: from, endDate: to);

      verify(() => timeEntries.getByDateRange(from, to)).called(1);
      verifyNever(() => timeEntries.getAll());
    });

    test('writes an empty data array rather than failing on no entries', () async {
      final data = await exportEntries([]);

      expect(data, isEmpty);
    });
  });
}
