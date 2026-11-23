import 'package:equatable/equatable.dart';

import '../../../data/models/client_model.dart';
import '../../../data/models/project_client_model.dart';

abstract class ClientState extends Equatable {
  const ClientState();

  @override
  List<Object?> get props => [];
}

class ClientInitial extends ClientState {
  const ClientInitial();
}

class ClientLoaded extends ClientState {
  final List<ClientModel> clients;
  final List<ProjectClientModel> links;

  /// Set when the last action was refused, e.g. deleting a client that has invoices.
  final String? message;

  const ClientLoaded({required this.clients, required this.links, this.message});

  List<ProjectClientModel> linksOfClient(String clientId) => links.where((l) => l.clientId == clientId).toList();

  @override
  List<Object?> get props => [clients, links, message];
}

class ClientError extends ClientState {
  final String message;
  const ClientError(this.message);

  @override
  List<Object?> get props => [message];
}
