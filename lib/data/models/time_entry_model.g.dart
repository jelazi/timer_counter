// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_entry_model.dart';

class TimeEntryModelAdapter extends TypeAdapter<TimeEntryModel> {
  @override
  final int typeId = 3;

  @override
  TimeEntryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimeEntryModel(
      id: fields[0] as String,
      projectId: fields[1] as String,
      taskId: fields[2] as String,
      startTime: fields[3] as DateTime,
      endTime: fields[4] as DateTime?,
      durationSeconds: fields[5] as int? ?? 0,
      notes: fields[6] as String? ?? '',
      createdAt: fields[7] as DateTime,
      isBillable: fields[8] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, TimeEntryModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.taskId)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.durationSeconds)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.isBillable);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeEntryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
