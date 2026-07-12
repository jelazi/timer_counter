import 'package:flutter/foundation.dart';

import '../../data/models/category_model.dart';
import '../../data/models/monthly_hours_target_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/standalone_invoice_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/monthly_hours_target_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/standalone_invoice_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import 'pocketbase_sync_service.dart';

/// Time entries from one calendar day that exist in a snapshot but not in the
/// live data.
@immutable
class MissingDay {
  /// Midnight of the day, derived from each entry's `startTime`.
  final DateTime day;
  final List<TimeEntryModel> entries;

  const MissingDay({required this.day, required this.entries});

  /// `YYYY-MM-DD`, used as the selection key when restoring specific days.
  String get key => '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  int get totalSeconds => entries.fold(0, (sum, e) => sum + e.actualDurationSeconds);
}

/// What a snapshot holds that the live data no longer does.
@immutable
class SnapshotDiff {
  final String snapshotPath;
  final DateTime snapshotDate;

  final List<CategoryModel> missingCategories;
  final List<ProjectModel> missingProjects;
  final List<TaskModel> missingTasks;
  final List<TimeEntryModel> missingTimeEntries;
  final List<MonthlyHoursTargetModel> missingTargets;
  final List<StandaloneInvoiceModel> missingInvoices;

  /// Time entries created since the snapshot. Expected and harmless — surfaced
  /// only so the UI can explain why the two sides differ.
  final int addedTimeEntries;

  const SnapshotDiff({
    required this.snapshotPath,
    required this.snapshotDate,
    this.missingCategories = const [],
    this.missingProjects = const [],
    this.missingTasks = const [],
    this.missingTimeEntries = const [],
    this.missingTargets = const [],
    this.missingInvoices = const [],
    this.addedTimeEntries = 0,
  });

  bool get hasLoss => missingTimeEntries.isNotEmpty || missingProjects.isNotEmpty || missingTasks.isNotEmpty || missingCategories.isNotEmpty || missingTargets.isNotEmpty || missingInvoices.isNotEmpty;

  int get totalMissing => missingCategories.length + missingProjects.length + missingTasks.length + missingTimeEntries.length + missingTargets.length + missingInvoices.length;

  /// Missing time entries grouped by the day they were tracked on, newest first.
  List<MissingDay> get missingDays {
    final byDay = <String, List<TimeEntryModel>>{};
    for (final entry in missingTimeEntries) {
      final day = DateTime(entry.startTime.year, entry.startTime.month, entry.startTime.day);
      byDay.putIfAbsent(day.toIso8601String(), () => []).add(entry);
    }

    final days = byDay.entries.map((e) => MissingDay(day: DateTime.parse(e.key), entries: e.value)).toList();
    return days..sort((a, b) => b.day.compareTo(a.day));
  }
}

/// Outcome of restoring missing records.
@immutable
class RestoreResult {
  final int entriesRestored;
  final int projectsRestored;
  final int tasksRestored;
  final int categoriesRestored;
  final int targetsRestored;
  final int invoicesRestored;
  final bool pushedToServer;
  final String? error;

  const RestoreResult({
    this.entriesRestored = 0,
    this.projectsRestored = 0,
    this.tasksRestored = 0,
    this.categoriesRestored = 0,
    this.targetsRestored = 0,
    this.invoicesRestored = 0,
    this.pushedToServer = false,
    this.error,
  });

  bool get hasError => error != null;

  int get total => entriesRestored + projectsRestored + tasksRestored + categoriesRestored + targetsRestored + invoicesRestored;
}

/// Compares a snapshot against the live data and puts back what went missing.
class SnapshotDiffService {
  final CategoryRepository _categoryRepository;
  final ProjectRepository _projectRepository;
  final TaskRepository _taskRepository;
  final TimeEntryRepository _timeEntryRepository;
  final MonthlyHoursTargetRepository _monthlyTargetRepository;
  final StandaloneInvoiceRepository _standaloneInvoiceRepository;

  SnapshotDiffService({
    required CategoryRepository categoryRepository,
    required ProjectRepository projectRepository,
    required TaskRepository taskRepository,
    required TimeEntryRepository timeEntryRepository,
    required MonthlyHoursTargetRepository monthlyTargetRepository,
    required StandaloneInvoiceRepository standaloneInvoiceRepository,
  }) : _categoryRepository = categoryRepository,
       _projectRepository = projectRepository,
       _taskRepository = taskRepository,
       _timeEntryRepository = timeEntryRepository,
       _monthlyTargetRepository = monthlyTargetRepository,
       _standaloneInvoiceRepository = standaloneInvoiceRepository;

  /// Find everything present in [snapshot] but absent from the live store.
  SnapshotDiff compare(Map<String, dynamic> snapshot, {required String snapshotPath, required DateTime snapshotDate}) {
    final liveEntryIds = _timeEntryRepository.getAll().map((e) => e.id).toSet();

    final snapshotEntries = _decode(snapshot['time_entries'], TimeEntryModel.fromJson);
    final snapshotEntryIds = snapshotEntries.map((e) => e.id).toSet();

    return SnapshotDiff(
      snapshotPath: snapshotPath,
      snapshotDate: snapshotDate,
      missingCategories: _missing(_decode(snapshot['categories'], CategoryModel.fromJson), _categoryRepository.getAll().map((c) => c.id).toSet(), (c) => c.id),
      missingProjects: _missing(_decode(snapshot['projects'], ProjectModel.fromJson), _projectRepository.getAll().map((p) => p.id).toSet(), (p) => p.id),
      missingTasks: _missing(_decode(snapshot['tasks'], TaskModel.fromJson), _taskRepository.getAll().map((t) => t.id).toSet(), (t) => t.id),
      missingTimeEntries: _missing(snapshotEntries, liveEntryIds, (e) => e.id),
      missingTargets: _missing(_decode(snapshot['monthly_targets'], MonthlyHoursTargetModel.fromJson), _monthlyTargetRepository.getAll().map((m) => m.id).toSet(), (m) => m.id),
      missingInvoices: _missing(_decode(snapshot['standalone_invoices'], StandaloneInvoiceModel.fromJson), _standaloneInvoiceRepository.getAll().map((i) => i.id).toSet(), (i) => i.id),
      addedTimeEntries: liveEntryIds.difference(snapshotEntryIds).length,
    );
  }

  /// Write missing records back into the local store.
  ///
  /// When [onlyDays] is given, only time entries tracked on those days (see
  /// [MissingDay.key]) are restored — but the projects and tasks they depend on
  /// are always restored regardless, since a restored entry pointing at a
  /// deleted project would be invisible in every screen.
  ///
  /// With [syncService] supplied, restored records are also pushed back to the
  /// server; otherwise the next reconcile would simply delete them again.
  Future<RestoreResult> restoreMissing(
    SnapshotDiff diff, {
    Set<String>? onlyDays,
    PocketBaseSyncService? syncService,
  }) async {
    try {
      final entries = onlyDays == null ? diff.missingTimeEntries : diff.missingTimeEntries.where((e) => onlyDays.contains(_dayKey(e.startTime))).toList();

      // Parents first, so nothing is briefly orphaned.
      for (final category in diff.missingCategories) {
        await _categoryRepository.add(category);
      }
      for (final project in diff.missingProjects) {
        await _projectRepository.add(project);
      }
      for (final task in diff.missingTasks) {
        await _taskRepository.add(task);
      }
      for (final entry in entries) {
        await _timeEntryRepository.add(entry);
      }
      for (final target in diff.missingTargets) {
        await _monthlyTargetRepository.add(target);
      }
      for (final invoice in diff.missingInvoices) {
        await _standaloneInvoiceRepository.add(invoice);
      }

      bool pushed = false;
      if (syncService != null && syncService.isSignedIn) {
        for (final category in diff.missingCategories) {
          await syncService.pushCategory(category);
        }
        for (final project in diff.missingProjects) {
          await syncService.pushProject(project);
        }
        for (final task in diff.missingTasks) {
          await syncService.pushTask(task);
        }
        for (final entry in entries) {
          await syncService.pushTimeEntry(entry);
        }
        for (final target in diff.missingTargets) {
          await syncService.pushMonthlyTarget(target);
        }
        pushed = true;
      }

      return RestoreResult(
        entriesRestored: entries.length,
        projectsRestored: diff.missingProjects.length,
        tasksRestored: diff.missingTasks.length,
        categoriesRestored: diff.missingCategories.length,
        targetsRestored: diff.missingTargets.length,
        invoicesRestored: diff.missingInvoices.length,
        pushedToServer: pushed,
      );
    } catch (e) {
      debugPrint('[SnapshotDiff] Restore failed: $e');
      return RestoreResult(error: e.toString());
    }
  }

  /// Put a single journalled record back, e.g. from the deletion log.
  Future<bool> restoreJournalledRecord(String collection, Map<String, dynamic> payload, {PocketBaseSyncService? syncService}) async {
    try {
      switch (collection) {
        case 'categories':
          final model = CategoryModel.fromJson(payload);
          await _categoryRepository.add(model);
          await syncService?.pushCategory(model);
        case 'projects':
          final model = ProjectModel.fromJson(payload);
          await _projectRepository.add(model);
          await syncService?.pushProject(model);
        case 'tasks':
          final model = TaskModel.fromJson(payload);
          await _taskRepository.add(model);
          await syncService?.pushTask(model);
        case 'time_entries':
          final model = TimeEntryModel.fromJson(payload);
          await _timeEntryRepository.add(model);
          await syncService?.pushTimeEntry(model);
        case 'monthly_hours_targets':
          final model = MonthlyHoursTargetModel.fromJson(payload);
          await _monthlyTargetRepository.add(model);
          await syncService?.pushMonthlyTarget(model);
        case 'standalone_invoices':
          await _standaloneInvoiceRepository.add(StandaloneInvoiceModel.fromJson(payload));
        default:
          return false;
      }
      return true;
    } catch (e) {
      debugPrint('[SnapshotDiff] Failed to restore $collection record: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  List<T> _decode<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
    if (value is! List) return const [];
    final result = <T>[];
    for (final item in value) {
      if (item is! Map) continue;
      try {
        result.add(fromJson(item.cast<String, dynamic>()));
      } catch (e) {
        debugPrint('[SnapshotDiff] Skipping malformed record: $e');
      }
    }
    return result;
  }

  List<T> _missing<T>(List<T> snapshotItems, Set<String> liveIds, String Function(T) getId) {
    return snapshotItems.where((item) => !liveIds.contains(getId(item))).toList();
  }

  static String _dayKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
