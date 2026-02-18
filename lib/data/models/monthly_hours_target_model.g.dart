// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_hours_target_model.dart';

class MonthlyHoursTargetModelAdapter extends TypeAdapter<MonthlyHoursTargetModel> {
  @override
  final int typeId = 6;

  @override
  MonthlyHoursTargetModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return MonthlyHoursTargetModel(
      id: fields[0] as String,
      name: fields[1] as String? ?? '',
      targetHours: (fields[2] as num?)?.toDouble() ?? 0.0,
      projectIds: (fields[3] as List?)?.cast<String>() ?? [],
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MonthlyHoursTargetModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.targetHours)
      ..writeByte(3)
      ..write(obj.projectIds)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is MonthlyHoursTargetModelAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
