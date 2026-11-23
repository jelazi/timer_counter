// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClientModelAdapter extends TypeAdapter<ClientModel> {
  @override
  final typeId = 9;

  @override
  ClientModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return ClientModel(
      id: fields[0] as String,
      name: fields[1] as String,
      addressLine1: fields[2] == null ? '' : fields[2] as String,
      addressLine2: fields[3] == null ? '' : fields[3] as String,
      ico: fields[4] == null ? '' : fields[4] as String,
      dic: fields[5] == null ? '' : fields[5] as String,
      email: fields[6] == null ? '' : fields[6] as String,
      phone: fields[7] == null ? '' : fields[7] as String,
      notes: fields[8] == null ? '' : fields[8] as String,
      isArchived: fields[9] == null ? false : fields[9] as bool,
      createdAt: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ClientModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.addressLine1)
      ..writeByte(3)
      ..write(obj.addressLine2)
      ..writeByte(4)
      ..write(obj.ico)
      ..writeByte(5)
      ..write(obj.dic)
      ..writeByte(6)
      ..write(obj.email)
      ..writeByte(7)
      ..write(obj.phone)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.isArchived)
      ..writeByte(10)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ClientModelAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
