import 'package:equatable/equatable.dart';

import '../../../data/models/task_model.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();

  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {
  final String projectId;
  const LoadTasks(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

class LoadAllTasks extends TaskEvent {
  const LoadAllTasks();
}

class AddTask extends TaskEvent {
  final TaskModel task;
  const AddTask(this.task);

  @override
  List<Object?> get props => [task];
}

class UpdateTask extends TaskEvent {
  final TaskModel task;
  const UpdateTask(this.task);

  @override
  List<Object?> get props => [task];
}

class DeleteTask extends TaskEvent {
  final String taskId;
  final String projectId;
  const DeleteTask({required this.taskId, required this.projectId});

  @override
  List<Object?> get props => [taskId, projectId];
}
