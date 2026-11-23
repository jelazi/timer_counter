import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

import '../../core/utils/json_utils.dart';
import 'invoice_settings.dart';

part 'client_model.g.dart';

/// A company the user invoices. Linked to projects through [ProjectClientModel].
@HiveType(typeId: 9)
class ClientModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String addressLine1;

  @HiveField(3)
  final String addressLine2;

  @HiveField(4)
  final String ico;

  @HiveField(5)
  final String dic;

  @HiveField(6)
  final String email;

  @HiveField(7)
  final String phone;

  @HiveField(8)
  final String notes;

  @HiveField(9)
  final bool isArchived;

  @HiveField(10)
  final DateTime createdAt;

  const ClientModel({
    required this.id,
    required this.name,
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.ico = '',
    this.dic = '',
    this.email = '',
    this.phone = '',
    this.notes = '',
    this.isArchived = false,
    required this.createdAt,
  });

  /// The client as an invoice party, the shape the PDF invoice prints.
  InvoiceParty toInvoiceParty() => InvoiceParty(name: name, addressLine1: addressLine1, addressLine2: addressLine2, ico: ico, dic: dic, phone: phone, email: email);

  ClientModel copyWith({
    String? id,
    String? name,
    String? addressLine1,
    String? addressLine2,
    String? ico,
    String? dic,
    String? email,
    String? phone,
    String? notes,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      ico: ico ?? this.ico,
      dic: dic ?? this.dic,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'addressLine1': addressLine1,
    'addressLine2': addressLine2,
    'ico': ico,
    'dic': dic,
    'email': email,
    'phone': phone,
    'notes': notes,
    'isArchived': isArchived,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ClientModel.fromJson(Map<String, dynamic> json) => ClientModel(
    id: parseString(json['id']),
    name: parseString(json['name']),
    addressLine1: parseString(json['addressLine1']),
    addressLine2: parseString(json['addressLine2']),
    ico: parseString(json['ico']),
    dic: parseString(json['dic']),
    email: parseString(json['email']),
    phone: parseString(json['phone']),
    notes: parseString(json['notes']),
    isArchived: parseBool(json['isArchived']),
    createdAt: parseDate(json['createdAt']),
  );

  @override
  List<Object?> get props => [id, name, addressLine1, addressLine2, ico, dic, email, phone, notes, isArchived, createdAt];
}
