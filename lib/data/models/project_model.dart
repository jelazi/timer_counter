import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'project_model.g.dart';

@HiveType(typeId: 1)
class ProjectModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? categoryId;

  @HiveField(3)
  final int colorValue;

  @HiveField(4)
  final double hourlyRate;

  @HiveField(5)
  final double plannedTimeHours;

  @HiveField(6)
  final double plannedBudget;

  @HiveField(7)
  final DateTime? startDate;

  @HiveField(8)
  final DateTime? dueDate;

  @HiveField(9)
  final String notes;

  @HiveField(10)
  final bool isArchived;

  @HiveField(11)
  final bool isBillable;

  @HiveField(12)
  final DateTime createdAt;

  @HiveField(13)
  final double monthlyRequiredHours;

  const ProjectModel({
    required this.id,
    required this.name,
    this.categoryId,
    required this.colorValue,
    this.hourlyRate = 0.0,
    this.plannedTimeHours = 0.0,
    this.plannedBudget = 0.0,
    this.startDate,
    this.dueDate,
    this.notes = '',
    this.isArchived = false,
    this.isBillable = true,
    required this.createdAt,
    this.monthlyRequiredHours = 0.0,
  });

  ProjectModel copyWith({
    String? id,
    String? name,
    String? categoryId,
    bool clearCategoryId = false,
    int? colorValue,
    double? hourlyRate,
    double? plannedTimeHours,
    double? plannedBudget,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? notes,
    bool? isArchived,
    bool? isBillable,
    DateTime? createdAt,
    double? monthlyRequiredHours,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      colorValue: colorValue ?? this.colorValue,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      plannedTimeHours: plannedTimeHours ?? this.plannedTimeHours,
      plannedBudget: plannedBudget ?? this.plannedBudget,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      isBillable: isBillable ?? this.isBillable,
      createdAt: createdAt ?? this.createdAt,
      monthlyRequiredHours: monthlyRequiredHours ?? this.monthlyRequiredHours,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    categoryId,
    colorValue,
    hourlyRate,
    plannedTimeHours,
    plannedBudget,
    startDate,
    dueDate,
    notes,
    isArchived,
    isBillable,
    createdAt,
    monthlyRequiredHours,
  ];
}
