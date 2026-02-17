import 'package:equatable/equatable.dart';

abstract class TimerEvent extends Equatable {
  const TimerEvent();

  @override
  List<Object?> get props => [];
}

class LoadRunningTimers extends TimerEvent {
  const LoadRunningTimers();
}

class StartTimer extends TimerEvent {
  final String projectId;
  final String taskId;
  final String notes;

  const StartTimer({
    required this.projectId,
    required this.taskId,
    this.notes = '',
  });

  @override
  List<Object?> get props => [projectId, taskId, notes];
}

class StopTimer extends TimerEvent {
  final String timerId;
  const StopTimer(this.timerId);

  @override
  List<Object?> get props => [timerId];
}

class StopAllTimers extends TimerEvent {
  const StopAllTimers();
}

class TickTimers extends TimerEvent {
  const TickTimers();
}

class UpdateTimerNotes extends TimerEvent {
  final String timerId;
  final String notes;
  const UpdateTimerNotes({required this.timerId, required this.notes});

  @override
  List<Object?> get props => [timerId, notes];
}
