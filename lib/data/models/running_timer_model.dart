import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'running_timer_model.g.dart';

@HiveType(typeId: 4)
class RunningTimerModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String taskId;

  @HiveField(3)
  final DateTime startTime;

  @HiveField(4)
  final String notes;

  const RunningTimerModel({
    required this.id,
    required this.projectId,
    required this.taskId,
    required this.startTime,
    this.notes = '',
  });

  /// Get elapsed seconds from start time to now
  int get elapsedSeconds => DateTime.now().difference(startTime).inSeconds;

  RunningTimerModel copyWith({
    String? id,
    String? projectId,
    String? taskId,
    DateTime? startTime,
    String? notes,
  }) {
    return RunningTimerModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      taskId: taskId ?? this.taskId,
      startTime: startTime ?? this.startTime,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [id, projectId, taskId, startTime, notes];
}
