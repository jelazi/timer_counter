import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/pocketbase_sync_service.dart';
import '../../../data/models/project_client_model.dart';
import '../../../data/repositories/client_repository.dart';
import '../../../data/repositories/project_client_repository.dart';
import '../../../data/repositories/standalone_invoice_repository.dart';
import 'client_event.dart';
import 'client_state.dart';

class ClientBloc extends Bloc<ClientEvent, ClientState> {
  final ClientRepository _clientRepository;
  final ProjectClientRepository _linkRepository;
  final StandaloneInvoiceRepository _invoiceRepository;
  final PocketBaseSyncService? _syncService;
  StreamSubscription<SyncCollection>? _syncSubscription;

  ClientBloc({
    required ClientRepository clientRepository,
    required ProjectClientRepository projectClientRepository,
    required StandaloneInvoiceRepository invoiceRepository,
    PocketBaseSyncService? syncService,
  }) : _clientRepository = clientRepository,
       _linkRepository = projectClientRepository,
       _invoiceRepository = invoiceRepository,
       _syncService = syncService,
       super(const ClientInitial()) {
    on<LoadClients>(_onLoad);
    on<AddClient>(_onAdd);
    on<UpdateClient>(_onUpdate);
    on<DeleteClient>(_onDelete);
    on<SetProjectClients>(_onSetProjectClients);
    on<ClientsSyncedExternally>(_onLoad);

    _syncSubscription = _syncService?.onCollectionChanged.listen((collection) {
      if (collection == SyncCollection.clients || collection == SyncCollection.projectClients) {
        add(const ClientsSyncedExternally());
      }
    });
  }

  void _emitLoaded(Emitter<ClientState> emit, {String? message}) {
    emit(ClientLoaded(clients: _clientRepository.getAll(), links: _linkRepository.getAll(), message: message));
  }

  void _onLoad(ClientEvent event, Emitter<ClientState> emit) {
    try {
      _emitLoaded(emit);
    } catch (e) {
      emit(ClientError(e.toString()));
    }
  }

  Future<void> _onAdd(AddClient event, Emitter<ClientState> emit) async {
    await _clientRepository.add(event.client);
    _emitLoaded(emit);
    await _syncService?.pushClient(event.client);
  }

  Future<void> _onUpdate(UpdateClient event, Emitter<ClientState> emit) async {
    await _clientRepository.update(event.client);
    _emitLoaded(emit);
    await _syncService?.pushClient(event.client);
  }

  Future<void> _onDelete(DeleteClient event, Emitter<ClientState> emit) async {
    final invoiced = _invoiceRepository.getAll().any((i) => i.clientId == event.clientId);
    if (invoiced) {
      _emitLoaded(emit, message: 'clients.delete_has_invoices');
      return;
    }
    final links = _linkRepository.getByClient(event.clientId);
    for (final link in links) {
      await _linkRepository.delete(link.id);
    }
    await _clientRepository.delete(event.clientId);
    _emitLoaded(emit);
    for (final link in links) {
      await _syncService?.deleteProjectClient(link.id);
    }
    await _syncService?.deleteClient(event.clientId);
  }

  Future<void> _onSetProjectClients(SetProjectClients event, Emitter<ClientState> emit) async {
    final existing = {for (final link in _linkRepository.getByProject(event.projectId)) link.clientId: link};
    final removed = existing.values.where((link) => !event.clients.containsKey(link.clientId)).toList();
    final changed = <ProjectClientModel>[];

    var position = 0;
    for (final entry in event.clients.entries) {
      final current = existing[entry.key];
      if (current == null) {
        changed.add(
          ProjectClientModel(
            id: const Uuid().v4(),
            projectId: event.projectId,
            clientId: entry.key,
            serviceDescription: entry.value,
            createdAt: DateTime.now(),
            position: position,
          ),
        );
      } else if (current.serviceDescription != entry.value || current.position != position) {
        changed.add(current.copyWith(serviceDescription: entry.value, position: position));
      }
      position++;
    }

    for (final link in removed) {
      await _linkRepository.delete(link.id);
    }
    for (final link in changed) {
      await _linkRepository.add(link);
    }
    _emitLoaded(emit);

    for (final link in removed) {
      await _syncService?.deleteProjectClient(link.id);
    }
    for (final link in changed) {
      await _syncService?.pushProjectClient(link);
    }
  }

  @override
  Future<void> close() {
    _syncSubscription?.cancel();
    return super.close();
  }
}
