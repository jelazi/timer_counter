import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/deletion_journal_service.dart';
import '../models/task_model.dart';

class TaskRepository {
  late Box<TaskModel> _box;
  DeletionJournalService? _journal;

  Future<void> init() async {
    _box = await Hive.openBox<TaskModel>(AppConstants.tasksBox);
  }

  /// Record every deletion made through this repository into [journal].
  void attachJournal(DeletionJournalService journal) => _journal = journal;

  List<TaskModel> getAll() {
    return _box.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<TaskModel> getByProject(String projectId) {
    return _box.values.where((t) => t.projectId == projectId && !t.isArchived).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  TaskModel? getById(String id) {
    try {
      return _box.values.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(TaskModel task) async {
    await _box.put(task.id, task);
  }

  Future<void> update(TaskModel task) async {
    await _box.put(task.id, task);
  }

  Future<void> delete(String id) async {
    await _deleteAndJournal(id);
  }

  Future<void> deleteByProject(String projectId) async {
    final tasks = getByProject(projectId);
    for (final task in tasks) {
      await _deleteAndJournal(task.id, source: DeleteSource.cascade);
    }
  }

  Future<void> deleteAll() async {
    for (final task in _box.values.toList()) {
      _journal?.record(AppConstants.tasksBox, task.id, task.toJson(), source: DeleteSource.bulkClear);
    }
    await _box.clear();
  }

  /// Journal a record's full payload before it is removed, so it can be
  /// reconstructed later regardless of what triggered the delete.
  Future<void> _deleteAndJournal(String id, {DeleteSource? source}) async {
    final task = _box.get(id);
    if (task != null) {
      _journal?.record(AppConstants.tasksBox, id, task.toJson(), source: source);
    }
    await _box.delete(id);
  }
}
