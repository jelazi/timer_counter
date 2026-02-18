import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/firebase_sync_service_v2.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/time_entry_repository.dart';
import 'task_event.dart';
import 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository _taskRepository;
  final TimeEntryRepository _timeEntryRepository;
  final FirebaseSyncService? _firebaseSyncService;

  TaskBloc({required TaskRepository taskRepository, required TimeEntryRepository timeEntryRepository, FirebaseSyncService? firebaseSyncService})
    : _taskRepository = taskRepository,
      _timeEntryRepository = timeEntryRepository,
      _firebaseSyncService = firebaseSyncService,
      super(const TaskInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<LoadAllTasks>(_onLoadAllTasks);
    on<AddTask>(_onAddTask);
    on<UpdateTask>(_onUpdateTask);
    on<DeleteTask>(_onDeleteTask);
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
      _firebaseSyncService?.pushTask(event.task).catchError((e) => debugPrint('[TaskBloc] sync push error: $e'));
      final tasks = _taskRepository.getByProject(event.task.projectId);
      emit(TaskLoaded(tasks: tasks, projectId: event.task.projectId));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onUpdateTask(UpdateTask event, Emitter<TaskState> emit) async {
    try {
      await _taskRepository.update(event.task);
      _firebaseSyncService?.pushTask(event.task).catchError((e) => debugPrint('[TaskBloc] sync push error: $e'));
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
      // Sync deletions to Firebase
      for (final entry in entriesToDelete) {
        _firebaseSyncService?.deleteTimeEntry(entry.id).catchError((e) => debugPrint('[TaskBloc] sync delete error: $e'));
      }
      _firebaseSyncService?.deleteTask(event.taskId).catchError((e) => debugPrint('[TaskBloc] sync delete error: $e'));
      final tasks = _taskRepository.getByProject(event.projectId);
      emit(TaskLoaded(tasks: tasks, projectId: event.projectId));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }
}
