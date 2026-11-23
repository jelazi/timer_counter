import 'package:equatable/equatable.dart';

import '../../../data/models/client_model.dart';

abstract class ClientEvent extends Equatable {
  const ClientEvent();

  @override
  List<Object?> get props => [];
}

class LoadClients extends ClientEvent {
  const LoadClients();
}

class AddClient extends ClientEvent {
  final ClientModel client;
  const AddClient(this.client);

  @override
  List<Object?> get props => [client];
}

class UpdateClient extends ClientEvent {
  final ClientModel client;
  const UpdateClient(this.client);

  @override
  List<Object?> get props => [client];
}

/// Deletes a client and its project links. Refused when an invoice refers to it.
class DeleteClient extends ClientEvent {
  final String clientId;
  const DeleteClient(this.clientId);

  @override
  List<Object?> get props => [clientId];
}

/// Replaces the clients of one project: links to keep or add, with their service descriptions.
class SetProjectClients extends ClientEvent {
  final String projectId;

  /// clientId → service description, in the user's order; the first is the invoice default.
  final Map<String, String> clients;

  const SetProjectClients({required this.projectId, required this.clients});

  @override
  List<Object?> get props => [projectId, clients];
}

class ClientsSyncedExternally extends ClientEvent {
  const ClientsSyncedExternally();
}
