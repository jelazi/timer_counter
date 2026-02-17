import 'package:equatable/equatable.dart';

import '../../../data/models/project_model.dart';

abstract class ProjectEvent extends Equatable {
  const ProjectEvent();

  @override
  List<Object?> get props => [];
}

class LoadProjects extends ProjectEvent {
  const LoadProjects();
}

class AddProject extends ProjectEvent {
  final ProjectModel project;
  const AddProject(this.project);

  @override
  List<Object?> get props => [project];
}

class UpdateProject extends ProjectEvent {
  final ProjectModel project;
  const UpdateProject(this.project);

  @override
  List<Object?> get props => [project];
}

class DeleteProject extends ProjectEvent {
  final String projectId;
  const DeleteProject(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

class ArchiveProject extends ProjectEvent {
  final String projectId;
  const ArchiveProject(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

class UnarchiveProject extends ProjectEvent {
  final String projectId;
  const UnarchiveProject(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

class FilterProjects extends ProjectEvent {
  final String? categoryId;
  final bool showArchived;
  final String searchQuery;

  const FilterProjects({this.categoryId, this.showArchived = false, this.searchQuery = ''});

  @override
  List<Object?> get props => [categoryId, showArchived, searchQuery];
}
