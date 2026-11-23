import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'invoice_settings.dart';

/// The account owner's own billing identity. Exactly one per account.
class SupplierProfile extends Equatable {
  final InvoiceParty party;
  final String bankName;
  final String bankCode;
  final String swift;
  final String accountNumber;
  final String iban;
  final String issuerName;
  final String issuerEmail;
  final String reportFilename;
  final String reportRezijniFilename;
  final String invoiceFilename;

  /// When the profile was last edited; the newer side wins when two devices disagree.
  final DateTime updatedAt;

  const SupplierProfile({
    this.party = const InvoiceParty(),
    this.bankName = '',
    this.bankCode = '',
    this.swift = '',
    this.accountNumber = '',
    this.iban = '',
    this.issuerName = '',
    this.issuerEmail = '',
    this.reportFilename = defaultReportFilename,
    this.reportRezijniFilename = defaultReportRezijniFilename,
    this.invoiceFilename = defaultInvoiceFilename,
    required this.updatedAt,
  });

  static const String defaultReportFilename = 'report_{month}_{year}';
  static const String defaultReportRezijniFilename = 'report_{month}_{year}_rezijni';
  static const String defaultInvoiceFilename = 'faktura_{month}_{year}';

  bool get isEmpty => party.name.isEmpty && party.ico.isEmpty && accountNumber.isEmpty && iban.isEmpty;

  SupplierProfile copyWith({
    InvoiceParty? party,
    String? bankName,
    String? bankCode,
    String? swift,
    String? accountNumber,
    String? iban,
    String? issuerName,
    String? issuerEmail,
    String? reportFilename,
    String? reportRezijniFilename,
    String? invoiceFilename,
    DateTime? updatedAt,
  }) {
    return SupplierProfile(
      party: party ?? this.party,
      bankName: bankName ?? this.bankName,
      bankCode: bankCode ?? this.bankCode,
      swift: swift ?? this.swift,
      accountNumber: accountNumber ?? this.accountNumber,
      iban: iban ?? this.iban,
      issuerName: issuerName ?? this.issuerName,
      issuerEmail: issuerEmail ?? this.issuerEmail,
      reportFilename: reportFilename ?? this.reportFilename,
      reportRezijniFilename: reportRezijniFilename ?? this.reportRezijniFilename,
      invoiceFilename: invoiceFilename ?? this.invoiceFilename,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'party': party.toJson(),
    'bankName': bankName,
    'bankCode': bankCode,
    'swift': swift,
    'accountNumber': accountNumber,
    'iban': iban,
    'issuerName': issuerName,
    'issuerEmail': issuerEmail,
    'reportFilename': reportFilename,
    'reportRezijniFilename': reportRezijniFilename,
    'invoiceFilename': invoiceFilename,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SupplierProfile.fromJson(Map<String, dynamic> json) {
    return SupplierProfile(
      party: InvoiceParty.fromJson(parseMap(json['party'])),
      bankName: parseString(json['bankName']),
      bankCode: parseString(json['bankCode']),
      swift: parseString(json['swift']),
      accountNumber: parseString(json['accountNumber']),
      iban: parseString(json['iban']),
      issuerName: parseString(json['issuerName']),
      issuerEmail: parseString(json['issuerEmail']),
      reportFilename: parseString(json['reportFilename'], fallback: defaultReportFilename),
      reportRezijniFilename: parseString(json['reportRezijniFilename'], fallback: defaultReportRezijniFilename),
      invoiceFilename: parseString(json['invoiceFilename'], fallback: defaultInvoiceFilename),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  @override
  List<Object?> get props => [
    party.toJson().toString(),
    bankName,
    bankCode,
    swift,
    accountNumber,
    iban,
    issuerName,
    issuerEmail,
    reportFilename,
    reportRezijniFilename,
    invoiceFilename,
    updatedAt,
  ];
}
