import 'package:equatable/equatable.dart';

import '../../../data/models/task_model.dart';

abstract class TaskState extends Equatable {
  const TaskState();

  @override
  List<Object?> get props => [];
}

class TaskInitial extends TaskState {
  const TaskInitial();
}

class TaskLoading extends TaskState {
  const TaskLoading();
}

class TaskLoaded extends TaskState {
  final List<TaskModel> tasks;
  final String? projectId;

  const TaskLoaded({required this.tasks, this.projectId});

  @override
  List<Object?> get props => [tasks, projectId];
}

class TaskError extends TaskState {
  final String message;
  const TaskError(this.message);

  @override
  List<Object?> get props => [message];
}
