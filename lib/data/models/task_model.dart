import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 2)
class TaskModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String projectId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final double? hourlyRate;

  @HiveField(4)
  final bool isBillable;

  @HiveField(5)
  final String notes;

  @HiveField(6)
  final bool isArchived;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final int colorValue;

  const TaskModel({
    required this.id,
    required this.projectId,
    required this.name,
    this.hourlyRate,
    this.isBillable = true,
    this.notes = '',
    this.isArchived = false,
    required this.createdAt,
    this.colorValue = 0xFF6366F1,
  });

  TaskModel copyWith({
    String? id,
    String? projectId,
    String? name,
    double? hourlyRate,
    bool clearHourlyRate = false,
    bool? isBillable,
    String? notes,
    bool? isArchived,
    DateTime? createdAt,
    int? colorValue,
  }) {
    return TaskModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      hourlyRate: clearHourlyRate ? null : (hourlyRate ?? this.hourlyRate),
      isBillable: isBillable ?? this.isBillable,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  @override
  List<Object?> get props => [
        id,
        projectId,
        name,
        hourlyRate,
        isBillable,
        notes,
        isArchived,
        createdAt,
        colorValue,
      ];
}
