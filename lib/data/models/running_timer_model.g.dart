// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'running_timer_model.dart';

class RunningTimerModelAdapter extends TypeAdapter<RunningTimerModel> {
  @override
  final int typeId = 4;

  @override
  RunningTimerModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RunningTimerModel(
      id: fields[0] as String,
      projectId: fields[1] as String,
      taskId: fields[2] as String,
      startTime: fields[3] as DateTime,
      notes: fields[4] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, RunningTimerModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.taskId)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunningTimerModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
