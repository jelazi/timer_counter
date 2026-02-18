// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_model.dart';

class ProjectModelAdapter extends TypeAdapter<ProjectModel> {
  @override
  final int typeId = 1;

  @override
  ProjectModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return ProjectModel(
      id: fields[0] as String,
      name: fields[1] as String,
      categoryId: fields[2] as String?,
      colorValue: fields[3] as int,
      hourlyRate: (fields[4] as num?)?.toDouble() ?? 0.0,
      plannedTimeHours: (fields[5] as num?)?.toDouble() ?? 0.0,
      plannedBudget: (fields[6] as num?)?.toDouble() ?? 0.0,
      startDate: fields[7] as DateTime?,
      dueDate: fields[8] as DateTime?,
      notes: fields[9] as String? ?? '',
      isArchived: fields[10] as bool? ?? false,
      isBillable: fields[11] as bool? ?? true,
      createdAt: fields[12] as DateTime,
      monthlyRequiredHours: (fields[13] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  void write(BinaryWriter writer, ProjectModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.categoryId)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.hourlyRate)
      ..writeByte(5)
      ..write(obj.plannedTimeHours)
      ..writeByte(6)
      ..write(obj.plannedBudget)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.dueDate)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.isArchived)
      ..writeByte(11)
      ..write(obj.isBillable)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.monthlyRequiredHours);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ProjectModelAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
