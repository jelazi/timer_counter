import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

import '../../core/utils/json_utils.dart';

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
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'categoryId': categoryId,
    'colorValue': colorValue,
    'hourlyRate': hourlyRate,
    'plannedTimeHours': plannedTimeHours,
    'plannedBudget': plannedBudget,
    'startDate': startDate?.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'notes': notes,
    'isArchived': isArchived,
    'isBillable': isBillable,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ProjectModel.fromJson(Map<String, dynamic> json) => ProjectModel(
    id: parseString(json['id']),
    name: parseString(json['name']),
    categoryId: json['categoryId'] == null ? null : parseString(json['categoryId']),
    colorValue: parseInt(json['colorValue']),
    hourlyRate: parseDouble(json['hourlyRate']),
    plannedTimeHours: parseDouble(json['plannedTimeHours']),
    plannedBudget: parseDouble(json['plannedBudget']),
    startDate: parseDateOrNull(json['startDate']),
    dueDate: parseDateOrNull(json['dueDate']),
    notes: parseString(json['notes']),
    isArchived: parseBool(json['isArchived']),
    isBillable: parseBool(json['isBillable'], fallback: true),
    createdAt: parseDate(json['createdAt']),
  );

  @override
  List<Object?> get props => [id, name, categoryId, colorValue, hourlyRate, plannedTimeHours, plannedBudget, startDate, dueDate, notes, isArchived, isBillable, createdAt];
}
