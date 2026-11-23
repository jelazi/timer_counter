import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/deletion_journal_service.dart';
import '../models/client_model.dart';

class ClientRepository {
  late Box<ClientModel> _box;
  DeletionJournalService? _journal;

  Future<void> init() async {
    _box = await Hive.openBox<ClientModel>(AppConstants.clientsBox);
  }

  /// Record every deletion made through this repository into [journal].
  void attachJournal(DeletionJournalService journal) => _journal = journal;

  List<ClientModel> getAll() => _box.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<ClientModel> getActive() => getAll().where((c) => !c.isArchived).toList();

  ClientModel? getById(String id) => _box.get(id);

  Future<void> add(ClientModel client) => _box.put(client.id, client);

  Future<void> update(ClientModel client) => _box.put(client.id, client);

  Future<void> delete(String id) async {
    final client = _box.get(id);
    if (client != null) {
      _journal?.record(AppConstants.clientsBox, id, client.toJson());
    }
    await _box.delete(id);
  }

  Future<void> deleteAll() async {
    for (final client in _box.values.toList()) {
      _journal?.record(AppConstants.clientsBox, client.id, client.toJson(), source: DeleteSource.bulkClear);
    }
    await _box.clear();
  }
}
