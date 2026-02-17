import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'time_entry_model.g.dart';

@HiveType(typeId: 3)
class TimeEntryModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String taskId;

  @HiveField(3)
  final DateTime startTime;

  @HiveField(4)
  final DateTime? endTime;

  @HiveField(5)
  final int durationSeconds;

  @HiveField(6)
  final String notes;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final bool isBillable;

  const TimeEntryModel({
    required this.id,
    required this.projectId,
    required this.taskId,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.notes = '',
    required this.createdAt,
    this.isBillable = true,
  });

  /// Calculate actual duration - if endTime is set use it, otherwise use stored duration
  int get actualDurationSeconds {
    if (endTime != null) {
      return endTime!.difference(startTime).inSeconds;
    }
    return durationSeconds;
  }

  TimeEntryModel copyWith({
    String? id,
    String? projectId,
    String? taskId,
    DateTime? startTime,
    DateTime? endTime,
    bool clearEndTime = false,
    int? durationSeconds,
    String? notes,
    DateTime? createdAt,
    bool? isBillable,
  }) {
    return TimeEntryModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      taskId: taskId ?? this.taskId,
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      durationSeconds: durationSeconds ?? this.durationSeconds,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      isBillable: isBillable ?? this.isBillable,
    );
  }

  @override
  List<Object?> get props => [
        id,
        projectId,
        taskId,
        startTime,
        endTime,
        durationSeconds,
        notes,
        createdAt,
        isBillable,
      ];
}
