import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/time_entry_repository.dart';
import 'task_event.dart';
import 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository _taskRepository;
  final TimeEntryRepository _timeEntryRepository;

  TaskBloc({required TaskRepository taskRepository, required TimeEntryRepository timeEntryRepository})
    : _taskRepository = taskRepository,
      _timeEntryRepository = timeEntryRepository,
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
      final tasks = _taskRepository.getByProject(event.task.projectId);
      emit(TaskLoaded(tasks: tasks, projectId: event.task.projectId));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onUpdateTask(UpdateTask event, Emitter<TaskState> emit) async {
    try {
      await _taskRepository.update(event.task);
      final tasks = _taskRepository.getByProject(event.task.projectId);
      emit(TaskLoaded(tasks: tasks, projectId: event.task.projectId));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onDeleteTask(DeleteTask event, Emitter<TaskState> emit) async {
    try {
      await _timeEntryRepository.deleteByTask(event.taskId);
      await _taskRepository.delete(event.taskId);
      final tasks = _taskRepository.getByProject(event.projectId);
      emit(TaskLoaded(tasks: tasks, projectId: event.projectId));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }
}
