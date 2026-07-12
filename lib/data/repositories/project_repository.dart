import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/deletion_journal_service.dart';
import '../models/project_model.dart';

class ProjectRepository {
  late Box<ProjectModel> _box;
  DeletionJournalService? _journal;

  Future<void> init() async {
    _box = await Hive.openBox<ProjectModel>(AppConstants.projectsBox);
  }

  /// Record every deletion made through this repository into [journal].
  void attachJournal(DeletionJournalService journal) => _journal = journal;

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
    final project = _box.get(id);
    if (project != null) {
      _journal?.record(AppConstants.projectsBox, id, project.toJson());
    }
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

  Future<void> deleteAll() async {
    for (final project in _box.values.toList()) {
      _journal?.record(AppConstants.projectsBox, project.id, project.toJson(), source: DeleteSource.bulkClear);
    }
    await _box.clear();
  }
}
