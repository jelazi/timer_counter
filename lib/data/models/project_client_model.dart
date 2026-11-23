import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

import '../../core/utils/json_utils.dart';

part 'project_client_model.g.dart';

/// Links a project to a client it can be invoiced to. A project may have
/// several clients; the one at the top ([position] 0) is offered on an invoice.
@HiveType(typeId: 10)
class ProjectClientModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String clientId;

  /// Text of the invoice line for this project when billed to this client.
  @HiveField(3)
  final String serviceDescription;

  @HiveField(4)
  final DateTime createdAt;

  /// Order of the project's clients as the user arranged them; 0 is the invoice default.
  @HiveField(5)
  final int position;

  const ProjectClientModel({required this.id, required this.projectId, required this.clientId, this.serviceDescription = '', required this.createdAt, this.position = 0});

  ProjectClientModel copyWith({String? id, String? projectId, String? clientId, String? serviceDescription, DateTime? createdAt, int? position}) {
    return ProjectClientModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      clientId: clientId ?? this.clientId,
      serviceDescription: serviceDescription ?? this.serviceDescription,
      createdAt: createdAt ?? this.createdAt,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'clientId': clientId,
    'serviceDescription': serviceDescription,
    'createdAt': createdAt.toIso8601String(),
    'position': position,
  };

  factory ProjectClientModel.fromJson(Map<String, dynamic> json) => ProjectClientModel(
    id: parseString(json['id']),
    projectId: parseString(json['projectId']),
    clientId: parseString(json['clientId']),
    serviceDescription: parseString(json['serviceDescription']),
    createdAt: parseDate(json['createdAt']),
    position: parseInt(json['position']),
  );

  @override
  List<Object?> get props => [id, projectId, clientId, serviceDescription, createdAt, position];
}
