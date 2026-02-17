/// Represents a supplier or customer entity for invoice generation.
class InvoiceParty {
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String ico;
  final String dic;
  final String phone;
  final String email;

  const InvoiceParty({this.name = '', this.addressLine1 = '', this.addressLine2 = '', this.ico = '', this.dic = '', this.phone = '', this.email = ''});

  Map<String, dynamic> toJson() => {'name': name, 'addressLine1': addressLine1, 'addressLine2': addressLine2, 'ico': ico, 'dic': dic, 'phone': phone, 'email': email};

  factory InvoiceParty.fromJson(Map<dynamic, dynamic> json) => InvoiceParty(
    name: json['name'] as String? ?? '',
    addressLine1: json['addressLine1'] as String? ?? '',
    addressLine2: json['addressLine2'] as String? ?? '',
    ico: json['ico'] as String? ?? '',
    dic: json['dic'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
  );

  InvoiceParty copyWith({String? name, String? addressLine1, String? addressLine2, String? ico, String? dic, String? phone, String? email}) => InvoiceParty(
    name: name ?? this.name,
    addressLine1: addressLine1 ?? this.addressLine1,
    addressLine2: addressLine2 ?? this.addressLine2,
    ico: ico ?? this.ico,
    dic: dic ?? this.dic,
    phone: phone ?? this.phone,
    email: email ?? this.email,
  );

  String get displayLabel => name.isNotEmpty ? name : '(bez názvu)';

  @override
  String toString() => 'InvoiceParty($name)';
}

/// All invoice-related settings for PDF generation.
class InvoiceSettings {
  final InvoiceParty supplier;
  final InvoiceParty customer;
  final String description;
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

  const InvoiceSettings({
    this.supplier = const InvoiceParty(
      name: 'Lubomír Žižka',
      addressLine1: 'Na Hvězdě 55/3',
      addressLine2: '69151 Lanžhot',
      ico: '19164165',
      phone: '776122559',
      email: 'lzizka@gmail.com',
    ),
    this.customer = const InvoiceParty(name: 'Medutech s.r.o.', addressLine1: 'Beranových 130', addressLine2: '19900 PRAHA 18', ico: '08975922', dic: 'CZ08975922'),
    this.description = 'Vývoj aplikace Artemis',
    this.bankName = '',
    this.bankCode = '6210',
    this.swift = '',
    this.accountNumber = '670100-2200840281',
    this.iban = 'CZ2862106701002200840281',
    this.issuerName = 'Lubomír Žižka',
    this.issuerEmail = 'lzizka@gmail.com',
    this.reportFilename = 'report_{month}_{year}',
    this.reportRezijniFilename = 'report_{month}_{year}_rezijni',
    this.invoiceFilename = 'faktura_{month}_{year}',
  });

  InvoiceSettings copyWith({
    InvoiceParty? supplier,
    InvoiceParty? customer,
    String? description,
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
  }) => InvoiceSettings(
    supplier: supplier ?? this.supplier,
    customer: customer ?? this.customer,
    description: description ?? this.description,
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
  );
}
