import 'package:equatable/equatable.dart';

import '../../../data/models/project_model.dart';

abstract class ProjectState extends Equatable {
  const ProjectState();

  @override
  List<Object?> get props => [];
}

class ProjectInitial extends ProjectState {
  const ProjectInitial();
}

class ProjectLoading extends ProjectState {
  const ProjectLoading();
}

class ProjectLoaded extends ProjectState {
  final List<ProjectModel> projects;
  final List<ProjectModel> filteredProjects;
  final bool showArchived;
  final String? selectedCategoryId;
  final String searchQuery;

  const ProjectLoaded({required this.projects, required this.filteredProjects, this.showArchived = false, this.selectedCategoryId, this.searchQuery = ''});

  @override
  List<Object?> get props => [projects, filteredProjects, showArchived, selectedCategoryId, searchQuery];
}

class ProjectError extends ProjectState {
  final String message;
  const ProjectError(this.message);

  @override
  List<Object?> get props => [message];
}
