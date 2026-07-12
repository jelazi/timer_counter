import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timer_counter/core/services/snapshot_diff_service.dart';
import 'package:timer_counter/data/models/category_model.dart';
import 'package:timer_counter/data/models/monthly_hours_target_model.dart';
import 'package:timer_counter/data/models/project_model.dart';
import 'package:timer_counter/data/models/standalone_invoice_model.dart';
import 'package:timer_counter/data/models/task_model.dart';
import 'package:timer_counter/data/models/time_entry_model.dart';
import 'package:timer_counter/data/repositories/category_repository.dart';
import 'package:timer_counter/data/repositories/monthly_hours_target_repository.dart';
import 'package:timer_counter/data/repositories/project_repository.dart';
import 'package:timer_counter/data/repositories/standalone_invoice_repository.dart';
import 'package:timer_counter/data/repositories/task_repository.dart';
import 'package:timer_counter/data/repositories/time_entry_repository.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockProjectRepository extends Mock implements ProjectRepository {}

class MockTaskRepository extends Mock implements TaskRepository {}

class MockTimeEntryRepository extends Mock implements TimeEntryRepository {}

class MockMonthlyHoursTargetRepository extends Mock implements MonthlyHoursTargetRepository {}

class MockStandaloneInvoiceRepository extends Mock implements StandaloneInvoiceRepository {}

TimeEntryModel _entry(String id, DateTime start, {int seconds = 3600, String projectId = 'p1', String taskId = 't1'}) {
  return TimeEntryModel(
    id: id,
    projectId: projectId,
    taskId: taskId,
    startTime: start,
    endTime: start.add(Duration(seconds: seconds)),
    createdAt: start,
  );
}

ProjectModel _project(String id) => ProjectModel(id: id, name: 'Project $id', colorValue: 0xFF000000, createdAt: DateTime(2026));

TaskModel _task(String id, String projectId) => TaskModel(id: id, projectId: projectId, name: 'Task $id', createdAt: DateTime(2026));

void main() {
  late MockCategoryRepository categoryRepo;
  late MockProjectRepository projectRepo;
  late MockTaskRepository taskRepo;
  late MockTimeEntryRepository timeEntryRepo;
  late MockMonthlyHoursTargetRepository targetRepo;
  late MockStandaloneInvoiceRepository invoiceRepo;
  late SnapshotDiffService service;

  setUpAll(() {
    registerFallbackValue(_project('fallback'));
    registerFallbackValue(_task('fallback', 'p'));
    registerFallbackValue(_entry('fallback', DateTime(2026)));
    registerFallbackValue(CategoryModel(id: 'f', name: 'f', colorValue: 0, createdAt: DateTime(2026)));
    registerFallbackValue(MonthlyHoursTargetModel(id: 'f', name: 'f', targetHours: 0, projectIds: const [], createdAt: DateTime(2026)));
    registerFallbackValue(
      StandaloneInvoiceModel(id: 'f', invoiceNumber: 1, issueDate: DateTime(2026), dueDate: DateTime(2026), taxDate: DateTime(2026), createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    );
  });

  setUp(() {
    categoryRepo = MockCategoryRepository();
    projectRepo = MockProjectRepository();
    taskRepo = MockTaskRepository();
    timeEntryRepo = MockTimeEntryRepository();
    targetRepo = MockMonthlyHoursTargetRepository();
    invoiceRepo = MockStandaloneInvoiceRepository();

    // Default: the live store is empty unless a test says otherwise.
    when(() => categoryRepo.getAll()).thenReturn([]);
    when(() => projectRepo.getAll()).thenReturn([]);
    when(() => taskRepo.getAll()).thenReturn([]);
    when(() => timeEntryRepo.getAll()).thenReturn([]);
    when(() => targetRepo.getAll()).thenReturn([]);
    when(() => invoiceRepo.getAll()).thenReturn([]);

    when(() => categoryRepo.add(any())).thenAnswer((_) async {});
    when(() => projectRepo.add(any())).thenAnswer((_) async {});
    when(() => taskRepo.add(any())).thenAnswer((_) async {});
    when(() => timeEntryRepo.add(any())).thenAnswer((_) async {});
    when(() => targetRepo.add(any())).thenAnswer((_) async {});
    when(() => invoiceRepo.add(any())).thenAnswer((_) async {});

    service = SnapshotDiffService(
      categoryRepository: categoryRepo,
      projectRepository: projectRepo,
      taskRepository: taskRepo,
      timeEntryRepository: timeEntryRepo,
      monthlyTargetRepository: targetRepo,
      standaloneInvoiceRepository: invoiceRepo,
    );
  });

  Map<String, dynamic> snapshotOf({
    List<TimeEntryModel> entries = const [],
    List<ProjectModel> projects = const [],
    List<TaskModel> tasks = const [],
  }) {
    return {
      'backup_version': 2,
      'categories': const [],
      'projects': projects.map((p) => p.toJson()).toList(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'time_entries': entries.map((e) => e.toJson()).toList(),
      'monthly_targets': const [],
      'standalone_invoices': const [],
    };
  }

  SnapshotDiff compare(Map<String, dynamic> snapshot) => service.compare(snapshot, snapshotPath: '/tmp/s.json', snapshotDate: DateTime(2026, 7, 12));

  group('compare', () {
    test('reports no loss when the live store matches the snapshot', () {
      final entries = [_entry('e1', DateTime(2026, 7, 8, 9))];
      when(() => timeEntryRepo.getAll()).thenReturn(entries);

      final diff = compare(snapshotOf(entries: entries));

      expect(diff.hasLoss, isFalse);
      expect(diff.totalMissing, 0);
    });

    test('detects time entries present in the snapshot but gone from the live store', () {
      final kept = _entry('e1', DateTime(2026, 7, 8, 9));
      final lost = _entry('e2', DateTime(2026, 7, 8, 13));
      when(() => timeEntryRepo.getAll()).thenReturn([kept]);

      final diff = compare(snapshotOf(entries: [kept, lost]));

      expect(diff.hasLoss, isTrue);
      expect(diff.missingTimeEntries.map((e) => e.id), ['e2']);
    });

    test('does not flag entries created after the snapshot as loss', () {
      final old = _entry('e1', DateTime(2026, 7, 8, 9));
      final fresh = _entry('e2', DateTime(2026, 7, 12, 9));
      when(() => timeEntryRepo.getAll()).thenReturn([old, fresh]);

      final diff = compare(snapshotOf(entries: [old]));

      expect(diff.hasLoss, isFalse);
      expect(diff.addedTimeEntries, 1);
    });

    test('groups missing entries by tracked day, newest first', () {
      final a = _entry('e1', DateTime(2026, 7, 8, 9), seconds: 3600);
      final b = _entry('e2', DateTime(2026, 7, 8, 14), seconds: 1800);
      final c = _entry('e3', DateTime(2026, 7, 10, 9), seconds: 7200);

      final diff = compare(snapshotOf(entries: [a, b, c]));
      final days = diff.missingDays;

      expect(days.map((d) => d.key), ['2026-07-10', '2026-07-08']);
      expect(days.first.entries.length, 1);
      expect(days.last.entries.length, 2);
      expect(days.last.totalSeconds, 5400); // 1h + 30m
    });
  });

  group('restoreMissing', () {
    test('restores every missing entry when no day filter is given', () async {
      final lost = [_entry('e1', DateTime(2026, 7, 8, 9)), _entry('e2', DateTime(2026, 7, 10, 9))];
      final diff = compare(snapshotOf(entries: lost));

      final result = await service.restoreMissing(diff);

      expect(result.entriesRestored, 2);
      verify(() => timeEntryRepo.add(any())).called(2);
    });

    test('restores only the selected days', () async {
      final keep = _entry('e1', DateTime(2026, 7, 8, 9));
      final skip = _entry('e2', DateTime(2026, 7, 10, 9));
      final diff = compare(snapshotOf(entries: [keep, skip]));

      final result = await service.restoreMissing(diff, onlyDays: {'2026-07-08'});

      expect(result.entriesRestored, 1);
      final restored = verify(() => timeEntryRepo.add(captureAny())).captured.cast<TimeEntryModel>();
      expect(restored.single.id, 'e1');
    });

    test('restores the parent project and task, so a recovered entry is not orphaned', () async {
      final project = _project('p1');
      final task = _task('t1', 'p1');
      final entry = _entry('e1', DateTime(2026, 7, 8, 9));

      final diff = compare(snapshotOf(entries: [entry], projects: [project], tasks: [task]));

      final result = await service.restoreMissing(diff, onlyDays: {'2026-07-08'});

      expect(result.projectsRestored, 1);
      expect(result.tasksRestored, 1);
      expect(result.entriesRestored, 1);
      verify(() => projectRepo.add(any(that: isA<ProjectModel>().having((p) => p.id, 'id', 'p1')))).called(1);
      verify(() => taskRepo.add(any(that: isA<TaskModel>().having((t) => t.id, 'id', 't1')))).called(1);
    });

    test('restores parents even when their day is not selected', () async {
      // Otherwise a restored entry would point at a project that no longer exists.
      final project = _project('p1');
      final entry = _entry('e1', DateTime(2026, 7, 10, 9));

      final diff = compare(snapshotOf(entries: [entry], projects: [project]));

      final result = await service.restoreMissing(diff, onlyDays: const {});

      expect(result.entriesRestored, 0);
      expect(result.projectsRestored, 1);
    });
  });

  group('round-trip serialization', () {
    test('a time entry survives toJson/fromJson unchanged', () {
      final original = _entry('e1', DateTime(2026, 7, 8, 9, 30), seconds: 5400);
      expect(TimeEntryModel.fromJson(original.toJson()), original);
    });

    test('a project with null optional dates survives toJson/fromJson', () {
      final original = _project('p1');
      expect(ProjectModel.fromJson(original.toJson()), original);
    });

    test('malformed records are skipped rather than aborting the whole diff', () {
      // A snapshot file is long-lived on disk; one corrupt line must not cost
      // us every other record in it.
      final good = _entry('e1', DateTime(2026, 7, 8, 9));
      final snapshot = snapshotOf(entries: [good]);
      snapshot['time_entries'] = <dynamic>['not a record', good.toJson()];

      final diff = compare(snapshot);

      expect(diff.missingTimeEntries.map((e) => e.id), ['e1']);
    });
  });
}
