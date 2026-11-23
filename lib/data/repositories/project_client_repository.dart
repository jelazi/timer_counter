import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/deletion_journal_service.dart';
import '../models/project_client_model.dart';

class ProjectClientRepository {
  late Box<ProjectClientModel> _box;
  DeletionJournalService? _journal;

  Future<void> init() async {
    _box = await Hive.openBox<ProjectClientModel>(AppConstants.projectClientsBox);
  }

  /// Record every deletion made through this repository into [journal].
  void attachJournal(DeletionJournalService journal) => _journal = journal;

  List<ProjectClientModel> getAll() => _box.values.toList();

  ProjectClientModel? getById(String id) => _box.get(id);

  /// Links of one project in the user's order; the first is the invoice default.
  List<ProjectClientModel> getByProject(String projectId) => _ordered(_box.values.where((l) => l.projectId == projectId));

  List<ProjectClientModel> getByClient(String clientId) => _ordered(_box.values.where((l) => l.clientId == clientId));

  ProjectClientModel? find(String projectId, String clientId) {
    for (final link in _box.values) {
      if (link.projectId == projectId && link.clientId == clientId) return link;
    }
    return null;
  }

  /// Client ids that can be billed for [projectIds], each project's top client first.
  List<String> clientIdsForProjects(Iterable<String> projectIds) {
    final wanted = projectIds.toSet();
    final ids = <String>[];
    for (final link in _ordered(_box.values.where((l) => wanted.contains(l.projectId)))) {
      if (!ids.contains(link.clientId)) ids.add(link.clientId);
    }
    return ids;
  }

  Future<void> add(ProjectClientModel link) => _box.put(link.id, link);

  Future<void> update(ProjectClientModel link) => _box.put(link.id, link);

  Future<void> delete(String id) async {
    final link = _box.get(id);
    if (link != null) {
      _journal?.record(AppConstants.projectClientsBox, id, link.toJson());
    }
    await _box.delete(id);
  }

  Future<void> deleteAll() async {
    for (final link in _box.values.toList()) {
      _journal?.record(AppConstants.projectClientsBox, link.id, link.toJson(), source: DeleteSource.bulkClear);
    }
    await _box.clear();
  }

  /// By position; links with the same position (e.g. from before positions existed) newest first.
  static List<ProjectClientModel> _ordered(Iterable<ProjectClientModel> links) => links.toList()
    ..sort((a, b) {
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0 ? byPosition : b.createdAt.compareTo(a.createdAt);
    });
}
