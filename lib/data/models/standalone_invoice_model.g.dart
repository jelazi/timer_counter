// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'standalone_invoice_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvoiceLineItemAdapter extends TypeAdapter<InvoiceLineItem> {
  @override
  final typeId = 7;

  @override
  InvoiceLineItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return InvoiceLineItem(
      description: fields[0] == null ? '' : fields[0] as String,
      quantity: fields[1] == null ? 1 : (fields[1] as num).toDouble(),
      unit: fields[2] == null ? 'ks' : fields[2] as String,
      unitPrice: fields[3] == null ? 0 : (fields[3] as num).toDouble(),
      discountPercent: fields[4] == null ? 0 : (fields[4] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceLineItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.description)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.unitPrice)
      ..writeByte(4)
      ..write(obj.discountPercent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is InvoiceLineItemAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}

class StandaloneInvoiceModelAdapter extends TypeAdapter<StandaloneInvoiceModel> {
  @override
  final typeId = 8;

  @override
  StandaloneInvoiceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return StandaloneInvoiceModel(
      id: fields[0] as String,
      invoiceNumber: (fields[1] as num).toInt(),
      issueDate: fields[2] as DateTime,
      dueDate: fields[3] as DateTime,
      taxDate: fields[4] as DateTime,
      supplierJson: fields[5] == null ? const {} : (fields[5] as Map).cast<String, dynamic>(),
      customerJson: fields[6] == null ? const {} : (fields[6] as Map).cast<String, dynamic>(),
      lineItems: fields[7] == null ? const [] : (fields[7] as List).cast<InvoiceLineItem>(),
      bankName: fields[8] == null ? '' : fields[8] as String,
      bankCode: fields[9] == null ? '' : fields[9] as String,
      swift: fields[10] == null ? '' : fields[10] as String,
      accountNumber: fields[11] == null ? '' : fields[11] as String,
      iban: fields[12] == null ? '' : fields[12] as String,
      issuerName: fields[13] == null ? '' : fields[13] as String,
      issuerEmail: fields[14] == null ? '' : fields[14] as String,
      notes: fields[15] == null ? '' : fields[15] as String,
      createdAt: fields[16] as DateTime,
      updatedAt: fields[17] as DateTime,
      invoiceType: fields[18] == null ? 'standalone' : fields[18] as String,
      sourceProjectIds: fields[19] == null ? const [] : (fields[19] as List).cast<String>(),
      clientId: fields[20] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StandaloneInvoiceModel obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.invoiceNumber)
      ..writeByte(2)
      ..write(obj.issueDate)
      ..writeByte(3)
      ..write(obj.dueDate)
      ..writeByte(4)
      ..write(obj.taxDate)
      ..writeByte(5)
      ..write(obj.supplierJson)
      ..writeByte(6)
      ..write(obj.customerJson)
      ..writeByte(7)
      ..write(obj.lineItems)
      ..writeByte(8)
      ..write(obj.bankName)
      ..writeByte(9)
      ..write(obj.bankCode)
      ..writeByte(10)
      ..write(obj.swift)
      ..writeByte(11)
      ..write(obj.accountNumber)
      ..writeByte(12)
      ..write(obj.iban)
      ..writeByte(13)
      ..write(obj.issuerName)
      ..writeByte(14)
      ..write(obj.issuerEmail)
      ..writeByte(15)
      ..write(obj.notes)
      ..writeByte(16)
      ..write(obj.createdAt)
      ..writeByte(17)
      ..write(obj.updatedAt)
      ..writeByte(18)
      ..write(obj.invoiceType)
      ..writeByte(19)
      ..write(obj.sourceProjectIds)
      ..writeByte(20)
      ..write(obj.clientId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is StandaloneInvoiceModelAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
