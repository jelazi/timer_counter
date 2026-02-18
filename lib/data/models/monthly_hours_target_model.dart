import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'monthly_hours_target_model.g.dart';

@HiveType(typeId: 6)
class MonthlyHoursTargetModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double targetHours;

  @HiveField(3)
  final List<String> projectIds;

  @HiveField(4)
  final DateTime createdAt;

  const MonthlyHoursTargetModel({required this.id, required this.name, required this.targetHours, required this.projectIds, required this.createdAt});

  MonthlyHoursTargetModel copyWith({String? id, String? name, double? targetHours, List<String>? projectIds, DateTime? createdAt}) {
    return MonthlyHoursTargetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      targetHours: targetHours ?? this.targetHours,
      projectIds: projectIds ?? this.projectIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, targetHours, projectIds, createdAt];
}
