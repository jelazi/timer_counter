import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/pocketbase_sync_service.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/time_entry_repository.dart';
import 'task_event.dart';
import 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository _taskRepository;
  final TimeEntryRepository _timeEntryRepository;
  final PocketBaseSyncService? _syncService;
  StreamSubscription<SyncCollection>? _syncSubscription;

  TaskBloc({required TaskRepository taskRepository, required TimeEntryRepository timeEntryRepository, PocketBaseSyncService? syncService})
    : _taskRepository = taskRepository,
      _timeEntryRepository = timeEntryRepository,
      _syncService = syncService,
      super(const TaskInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<LoadAllTasks>(_onLoadAllTasks);
    on<AddTask>(_onAddTask);
    on<UpdateTask>(_onUpdateTask);
    on<DeleteTask>(_onDeleteTask);
    on<TasksSyncedExternally>(_onTasksSyncedExternally);

    _startSyncListener();
  }

  /// Reload tasks when a PocketBase subscription updates the local store.
  void _startSyncListener() {
    if (_syncService == null) return;
    _syncSubscription = _syncService.onCollectionChanged.listen((col) {
      if (col == SyncCollection.tasks) {
        add(const TasksSyncedExternally());
      }
    });
  }

  /// Reload preserving the current view (single project or all tasks).
  void _onTasksSyncedExternally(TasksSyncedExternally event, Emitter<TaskState> emit) {
    final currentState = state;
    if (currentState is TaskLoaded && currentState.projectId != null) {
      emit(TaskLoaded(tasks: _taskRepository.getByProject(currentState.projectId!), projectId: currentState.projectId));
    } else {
      emit(TaskLoaded(tasks: _taskRepository.getAll()));
    }
  }

  @override
  Future<void> close() {
    _syncSubscription?.cancel();
    return super.close();
  }

  void _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) {
    try {
      emit(const TaskLoading());
      final tasks = _taskRepository.getByProject(event.projectId);
      emit(TaskLoaded(tasks: tasks, projectId: event.projectId));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  void _onLoadAllTasks(LoadAllTasks event, Emitter<TaskState> emit) {
    try {
      emit(const TaskLoading());
      final tasks = _taskRepository.getAll();
      emit(TaskLoaded(tasks: tasks));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onAddTask(AddTask event, Emitter<TaskState> emit) async {
    try {
      await _taskRepository.add(event.task);
      _syncService?.pushTask(event.task).catchError((e) => debugPrint('[TaskBloc] sync push error: $e'));
      final tasks = _taskRepository.getByProject(event.task.projectId);
      emit(TaskLoaded(tasks: tasks, projectId: event.task.projectId));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onUpdateTask(UpdateTask event, Emitter<TaskState> emit) async {
    try {
      await _taskRepository.update(event.task);
      _syncService?.pushTask(event.task).catchError((e) => debugPrint('[TaskBloc] sync push error: $e'));
      final tasks = _taskRepository.getByProject(event.task.projectId);
      emit(TaskLoaded(tasks: tasks, projectId: event.task.projectId));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onDeleteTask(DeleteTask event, Emitter<TaskState> emit) async {
    try {
      final entriesToDelete = _timeEntryRepository.getByTask(event.taskId);
      await _timeEntryRepository.deleteByTask(event.taskId);
      await _taskRepository.delete(event.taskId);
      // Sync deletions to PocketBase
      for (final entry in entriesToDelete) {
        _syncService?.deleteTimeEntry(entry.id).catchError((e) => debugPrint('[TaskBloc] sync delete error: $e'));
      }
      _syncService?.deleteTask(event.taskId).catchError((e) => debugPrint('[TaskBloc] sync delete error: $e'));
      final tasks = _taskRepository.getByProject(event.projectId);
      emit(TaskLoaded(tasks: tasks, projectId: event.projectId));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }
}
