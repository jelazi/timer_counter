import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timer_counter/core/services/data_export_service.dart';
import 'package:timer_counter/data/models/client_model.dart';
import 'package:timer_counter/data/models/project_client_model.dart';
import 'package:timer_counter/data/models/project_model.dart';
import 'package:timer_counter/data/models/task_model.dart';
import 'package:timer_counter/data/models/time_entry_model.dart';
import 'package:timer_counter/data/repositories/client_repository.dart';
import 'package:timer_counter/data/repositories/project_client_repository.dart';
import 'package:timer_counter/data/repositories/project_repository.dart';
import 'package:timer_counter/data/repositories/settings_repository.dart';
import 'package:timer_counter/data/repositories/task_repository.dart';
import 'package:timer_counter/data/repositories/time_entry_repository.dart';

class MockTimeEntryRepository extends Mock implements TimeEntryRepository {}

class MockProjectRepository extends Mock implements ProjectRepository {}

class MockTaskRepository extends Mock implements TaskRepository {}

class MockClientRepository extends Mock implements ClientRepository {}

class MockProjectClientRepository extends Mock implements ProjectClientRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

TimeEntryModel _entry({String id = 'e1', DateTime? start, int seconds = 3600, bool isBillable = true, String notes = ''}) {
  final startTime = start ?? DateTime(2026, 11, 2, 9);
  return TimeEntryModel(
    id: id,
    projectId: 'p1',
    taskId: 't1',
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
  late MockClientRepository clients;
  late MockProjectClientRepository links;
  late MockSettingsRepository settings;
  late DataExportService service;
  late Directory tempDir;

  final project = ProjectModel(id: 'p1', name: '2. Artemis', colorValue: 0xFFFFA726, hourlyRate: 550, createdAt: DateTime(2026, 1, 1));
  final task = TaskModel(id: 't1', projectId: 'p1', name: 'Surgeon', createdAt: DateTime(2026, 1, 1));

  setUp(() async {
    timeEntries = MockTimeEntryRepository();
    projects = MockProjectRepository();
    tasks = MockTaskRepository();
    clients = MockClientRepository();
    links = MockProjectClientRepository();
    settings = MockSettingsRepository();

    when(() => settings.getCurrency()).thenReturn('CZK');
    when(() => settings.getRoundTime()).thenReturn(false);
    when(() => settings.getRoundToMinutes()).thenReturn(1);
    when(() => projects.getById('p1')).thenReturn(project);
    when(() => tasks.getById('t1')).thenReturn(task);
    when(() => links.getByProject('p1')).thenReturn([ProjectClientModel(id: 'l1', projectId: 'p1', clientId: 'c1', createdAt: DateTime(2026, 11, 1))]);
    when(() => clients.getById('c1')).thenReturn(ClientModel(id: 'c1', name: 'Medutech s.r.o.', createdAt: DateTime(2026, 11, 1)));

    service = DataExportService(
      timeEntryRepository: timeEntries,
      projectRepository: projects,
      taskRepository: tasks,
      clientRepository: clients,
      projectClientRepository: links,
      settingsRepository: settings,
    );
    tempDir = await Directory.systemTemp.createTemp('data_export_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<Map<String, dynamic>> exportJson(List<TimeEntryModel> entries) async {
    when(() => timeEntries.getAll()).thenReturn(entries);
    final path = '${tempDir.path}/export.json';
    await service.exportToJson(outputPath: path);
    return json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
  }

  test('the JSON names its own format and carries project, task and clients per entry', () async {
    final doc = await exportJson([_entry(seconds: 5400, notes: 'review')]);

    expect(doc['format'], 'timer_counter.export');
    expect(doc['version'], 1);
    final entry = (doc['entries'] as List).single as Map<String, dynamic>;
    expect(entry['project'], '2. Artemis');
    expect(entry['task'], 'Surgeon');
    expect(entry['clients'], ['Medutech s.r.o.']);
    expect(entry['duration_minutes'], 90);
    expect(entry['hours'], 1.5);
    expect(entry['amount'], 825.0);
    expect(entry['notes'], 'review');
    expect(doc['summary'], {'entries': 1, 'hours': 1.5, 'amount': 825.0});
  });

  test('a non-billable entry has no amount', () async {
    final doc = await exportJson([_entry(isBillable: false)]);

    expect(((doc['entries'] as List).single as Map)['amount'], 0.0);
  });

  test('entries are exported oldest first', () async {
    final doc = await exportJson([_entry(id: 'late', start: DateTime(2026, 11, 3, 9)), _entry(id: 'early', start: DateTime(2026, 11, 1, 9))]);

    expect((doc['entries'] as List).map((e) => (e as Map)['id']), ['early', 'late']);
  });

  test('the CSV has a header and one ;-separated row per entry with Czech decimals', () async {
    when(() => timeEntries.getByDateRange(any(), any())).thenReturn([_entry(seconds: 5400)]);
    final path = '${tempDir.path}/export.csv';

    await service.exportToCsv(outputPath: path, startDate: DateTime(2026, 11, 1), endDate: DateTime(2026, 11, 30));

    final lines = File(path).readAsLinesSync();
    expect(lines.first, DataExportService.csvColumns.join(';'));
    expect(lines[1], '2026-11-02;09:00;10:30;90;1,50;2. Artemis;Surgeon;Medutech s.r.o.;ano;550,00;825,00;CZK;');
  });

  group('rules kept from the previous export', () {
    test('rounds to the configured step and never exports zero minutes', () {
      expect(DataExportService.durationMinutes(_entry(seconds: 7 * 60), roundTime: true, roundToMinutes: 15), 1);
      expect(DataExportService.durationMinutes(_entry(seconds: 8 * 60), roundTime: true, roundToMinutes: 15), 15);
      expect(DataExportService.durationMinutes(_entry(seconds: 20), roundTime: false, roundToMinutes: 1), 1);
    });

    test('a task rate wins over the project rate, zero falls back to the project', () {
      expect(DataExportService.hourlyRate(project, task.copyWith(hourlyRate: 700)), 700);
      expect(DataExportService.hourlyRate(project, task.copyWith(hourlyRate: 0)), 550);
      expect(DataExportService.hourlyRate(null, null), 0);
    });
  });
}
