import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../models/project_model.dart';

class ProjectRepository {
  late Box<ProjectModel> _box;

  Future<void> init() async {
    _box = await Hive.openBox<ProjectModel>(AppConstants.projectsBox);
  }

  List<ProjectModel> getAll() {
    return _box.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<ProjectModel> getActive() {
    return _box.values.where((p) => !p.isArchived).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<ProjectModel> getArchived() {
    return _box.values.where((p) => p.isArchived).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<ProjectModel> getByCategory(String categoryId) {
    return _box.values.where((p) => p.categoryId == categoryId && !p.isArchived).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  ProjectModel? getById(String id) {
    try {
      return _box.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(ProjectModel project) async {
    await _box.put(project.id, project);
  }

  Future<void> update(ProjectModel project) async {
    await _box.put(project.id, project);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> archive(String id) async {
    final project = getById(id);
    if (project != null) {
      await _box.put(id, project.copyWith(isArchived: true));
    }
  }

  Future<void> unarchive(String id) async {
    final project = getById(id);
    if (project != null) {
      await _box.put(id, project.copyWith(isArchived: false));
    }
  }
}
