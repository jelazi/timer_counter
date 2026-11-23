// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_client_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectClientModelAdapter extends TypeAdapter<ProjectClientModel> {
  @override
  final typeId = 10;

  @override
  ProjectClientModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return ProjectClientModel(
      id: fields[0] as String,
      projectId: fields[1] as String,
      clientId: fields[2] as String,
      serviceDescription: fields[3] == null ? '' : fields[3] as String,
      createdAt: fields[4] as DateTime,
      position: fields[5] == null ? 0 : (fields[5] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, ProjectClientModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projectId)
      ..writeByte(2)
      ..write(obj.clientId)
      ..writeByte(3)
      ..write(obj.serviceDescription)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.position);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ProjectClientModelAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
