import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../models/task_model.dart';

class TaskRepository {
  late Box<TaskModel> _box;

  Future<void> init() async {
    _box = await Hive.openBox<TaskModel>(AppConstants.tasksBox);
  }

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
    await _box.delete(id);
  }

  Future<void> deleteByProject(String projectId) async {
    final tasks = getByProject(projectId);
    for (final task in tasks) {
      await _box.delete(task.id);
    }
  }
}
