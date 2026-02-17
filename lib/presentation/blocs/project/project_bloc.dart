import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/time_entry_repository.dart';
import 'project_event.dart';
import 'project_state.dart';

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final ProjectRepository _projectRepository;
  final TaskRepository _taskRepository;
  final TimeEntryRepository _timeEntryRepository;

  ProjectBloc({required ProjectRepository projectRepository, required TaskRepository taskRepository, required TimeEntryRepository timeEntryRepository})
    : _projectRepository = projectRepository,
      _taskRepository = taskRepository,
      _timeEntryRepository = timeEntryRepository,
      super(const ProjectInitial()) {
    on<LoadProjects>(_onLoadProjects);
    on<AddProject>(_onAddProject);
    on<UpdateProject>(_onUpdateProject);
    on<DeleteProject>(_onDeleteProject);
    on<ArchiveProject>(_onArchiveProject);
    on<UnarchiveProject>(_onUnarchiveProject);
    on<FilterProjects>(_onFilterProjects);
  }

  void _onLoadProjects(LoadProjects event, Emitter<ProjectState> emit) {
    try {
      emit(const ProjectLoading());
      final projects = _projectRepository.getAll();
      emit(ProjectLoaded(projects: projects, filteredProjects: projects.where((p) => !p.isArchived).toList()));
    } catch (e) {
      emit(ProjectError(e.toString()));
    }
  }

  Future<void> _onAddProject(AddProject event, Emitter<ProjectState> emit) async {
    try {
      await _projectRepository.add(event.project);
      _emitFilteredState(emit);
    } catch (e) {
      emit(ProjectError(e.toString()));
    }
  }

  Future<void> _onUpdateProject(UpdateProject event, Emitter<ProjectState> emit) async {
    try {
      await _projectRepository.update(event.project);
      _emitFilteredState(emit);
    } catch (e) {
      emit(ProjectError(e.toString()));
    }
  }

  Future<void> _onDeleteProject(DeleteProject event, Emitter<ProjectState> emit) async {
    try {
      await _timeEntryRepository.deleteByProject(event.projectId);
      await _taskRepository.deleteByProject(event.projectId);
      await _projectRepository.delete(event.projectId);
      _emitFilteredState(emit);
    } catch (e) {
      emit(ProjectError(e.toString()));
    }
  }

  Future<void> _onArchiveProject(ArchiveProject event, Emitter<ProjectState> emit) async {
    try {
      await _projectRepository.archive(event.projectId);
      _emitFilteredState(emit);
    } catch (e) {
      emit(ProjectError(e.toString()));
    }
  }

  Future<void> _onUnarchiveProject(UnarchiveProject event, Emitter<ProjectState> emit) async {
    try {
      await _projectRepository.unarchive(event.projectId);
      _emitFilteredState(emit);
    } catch (e) {
      emit(ProjectError(e.toString()));
    }
  }

  void _onFilterProjects(FilterProjects event, Emitter<ProjectState> emit) {
    try {
      final projects = _projectRepository.getAll();
      var filtered = projects.where((p) {
        if (!event.showArchived && p.isArchived) return false;
        if (event.showArchived && !p.isArchived) return false;
        if (event.categoryId != null && p.categoryId != event.categoryId) {
          return false;
        }
        if (event.searchQuery.isNotEmpty) {
          return p.name.toLowerCase().contains(event.searchQuery.toLowerCase());
        }
        return true;
      }).toList();

      emit(ProjectLoaded(projects: projects, filteredProjects: filtered, showArchived: event.showArchived, selectedCategoryId: event.categoryId, searchQuery: event.searchQuery));
    } catch (e) {
      emit(ProjectError(e.toString()));
    }
  }

  void _emitFilteredState(Emitter<ProjectState> emit) {
    final currentState = state;
    final projects = _projectRepository.getAll();

    if (currentState is ProjectLoaded) {
      var filtered = projects.where((p) {
        if (!currentState.showArchived && p.isArchived) return false;
        if (currentState.showArchived && !p.isArchived) return false;
        if (currentState.selectedCategoryId != null && p.categoryId != currentState.selectedCategoryId) {
          return false;
        }
        if (currentState.searchQuery.isNotEmpty) {
          return p.name.toLowerCase().contains(currentState.searchQuery.toLowerCase());
        }
        return true;
      }).toList();

      emit(
        ProjectLoaded(
          projects: projects,
          filteredProjects: filtered,
          showArchived: currentState.showArchived,
          selectedCategoryId: currentState.selectedCategoryId,
          searchQuery: currentState.searchQuery,
        ),
      );
    } else {
      emit(ProjectLoaded(projects: projects, filteredProjects: projects.where((p) => !p.isArchived).toList()));
    }
  }
}
