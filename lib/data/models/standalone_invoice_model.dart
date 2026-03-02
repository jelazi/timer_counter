import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'standalone_invoice_model.g.dart';

/// A single line item on a standalone invoice.
@HiveType(typeId: 7)
class InvoiceLineItem extends Equatable {
  @HiveField(0)
  final String description;

  @HiveField(1)
  final double quantity;

  @HiveField(2)
  final String unit;

  @HiveField(3)
  final double unitPrice;

  @HiveField(4)
  final double discountPercent;

  const InvoiceLineItem({this.description = '', this.quantity = 1, this.unit = 'ks', this.unitPrice = 0, this.discountPercent = 0});

  double get totalBeforeDiscount => quantity * unitPrice;
  double get discountAmount => totalBeforeDiscount * (discountPercent / 100);
  double get total => totalBeforeDiscount - discountAmount;

  InvoiceLineItem copyWith({String? description, double? quantity, String? unit, double? unitPrice, double? discountPercent}) => InvoiceLineItem(
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    unitPrice: unitPrice ?? this.unitPrice,
    discountPercent: discountPercent ?? this.discountPercent,
  );

  Map<String, dynamic> toJson() => {'description': description, 'quantity': quantity, 'unit': unit, 'unitPrice': unitPrice, 'discountPercent': discountPercent};

  factory InvoiceLineItem.fromJson(Map<dynamic, dynamic> json) => InvoiceLineItem(
    description: json['description'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
    unit: json['unit'] as String? ?? 'ks',
    unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
    discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
  );

  @override
  List<Object?> get props => [description, quantity, unit, unitPrice, discountPercent];
}

/// A standalone invoice (not derived from time tracking).
@HiveType(typeId: 8)
class StandaloneInvoiceModel extends Equatable {
  @HiveField(0)
  final String id;

  /// Sequential invoice number shared with time-based invoices.
  @HiveField(1)
  final int invoiceNumber;

  @HiveField(2)
  final DateTime issueDate;

  @HiveField(3)
  final DateTime dueDate;

  @HiveField(4)
  final DateTime taxDate;

  /// Supplier data stored as JSON map.
  @HiveField(5)
  final Map<String, dynamic> supplierJson;

  /// Customer data stored as JSON map.
  @HiveField(6)
  final Map<String, dynamic> customerJson;

  @HiveField(7)
  final List<InvoiceLineItem> lineItems;

  @HiveField(8)
  final String bankName;

  @HiveField(9)
  final String bankCode;

  @HiveField(10)
  final String swift;

  @HiveField(11)
  final String accountNumber;

  @HiveField(12)
  final String iban;

  @HiveField(13)
  final String issuerName;

  @HiveField(14)
  final String issuerEmail;

  @HiveField(15)
  final String notes;

  @HiveField(16)
  final DateTime createdAt;

  @HiveField(17)
  final DateTime updatedAt;

  /// Type of invoice: 'standalone' or 'time_based'.
  @HiveField(18)
  final String invoiceType;

  /// For time-based invoices: the project IDs used to generate this invoice.
  @HiveField(19)
  final List<String> sourceProjectIds;

  const StandaloneInvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.taxDate,
    this.supplierJson = const {},
    this.customerJson = const {},
    this.lineItems = const [],
    this.bankName = '',
    this.bankCode = '',
    this.swift = '',
    this.accountNumber = '',
    this.iban = '',
    this.issuerName = '',
    this.issuerEmail = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.invoiceType = 'standalone',
    this.sourceProjectIds = const [],
  });

  bool get isTimeBased => invoiceType == 'time_based';
  bool get isStandalone => invoiceType == 'standalone';

  /// Formatted invoice number string: YYYY-NNNNN
  String get invoiceNumberFormatted => '${issueDate.year}-${invoiceNumber.toString().padLeft(5, '0')}';

  /// Variable symbol for payment: YYYYNNNNN
  String get variableSymbol => '${issueDate.year}${invoiceNumber.toString().padLeft(5, '0')}';

  /// Total amount across all line items.
  double get totalAmount => lineItems.fold<double>(0, (sum, item) => sum + item.total);

  StandaloneInvoiceModel copyWith({
    String? id,
    int? invoiceNumber,
    DateTime? issueDate,
    DateTime? dueDate,
    DateTime? taxDate,
    Map<String, dynamic>? supplierJson,
    Map<String, dynamic>? customerJson,
    List<InvoiceLineItem>? lineItems,
    String? bankName,
    String? bankCode,
    String? swift,
    String? accountNumber,
    String? iban,
    String? issuerName,
    String? issuerEmail,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? invoiceType,
    List<String>? sourceProjectIds,
  }) => StandaloneInvoiceModel(
    id: id ?? this.id,
    invoiceNumber: invoiceNumber ?? this.invoiceNumber,
    issueDate: issueDate ?? this.issueDate,
    dueDate: dueDate ?? this.dueDate,
    taxDate: taxDate ?? this.taxDate,
    supplierJson: supplierJson ?? this.supplierJson,
    customerJson: customerJson ?? this.customerJson,
    lineItems: lineItems ?? this.lineItems,
    bankName: bankName ?? this.bankName,
    bankCode: bankCode ?? this.bankCode,
    swift: swift ?? this.swift,
    accountNumber: accountNumber ?? this.accountNumber,
    iban: iban ?? this.iban,
    issuerName: issuerName ?? this.issuerName,
    issuerEmail: issuerEmail ?? this.issuerEmail,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    invoiceType: invoiceType ?? this.invoiceType,
    sourceProjectIds: sourceProjectIds ?? this.sourceProjectIds,
  );

  @override
  List<Object?> get props => [
    id,
    invoiceNumber,
    issueDate,
    dueDate,
    taxDate,
    supplierJson,
    customerJson,
    lineItems,
    bankName,
    bankCode,
    swift,
    accountNumber,
    iban,
    issuerName,
    issuerEmail,
    notes,
    createdAt,
    updatedAt,
    invoiceType,
    sourceProjectIds,
  ];
}
