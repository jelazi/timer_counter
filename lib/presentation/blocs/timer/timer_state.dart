import 'package:equatable/equatable.dart';

import '../../../data/models/running_timer_model.dart';
import '../../../data/models/time_entry_model.dart';

abstract class TimerState extends Equatable {
  const TimerState();

  @override
  List<Object?> get props => [];
}

class TimerInitial extends TimerState {
  const TimerInitial();
}

class TimerRunning extends TimerState {
  final List<RunningTimerModel> runningTimers;
  final List<TimeEntryModel> todayEntries;
  final int totalTodaySeconds;

  const TimerRunning({required this.runningTimers, required this.todayEntries, required this.totalTodaySeconds});

  @override
  List<Object?> get props => [runningTimers, todayEntries, totalTodaySeconds];
}

class TimerError extends TimerState {
  final String message;
  const TimerError(this.message);

  @override
  List<Object?> get props => [message];
}
