import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/pocketbase_sync_service.dart';
import '../../data/models/invoice_settings.dart';
import '../../data/repositories/settings_repository.dart';

/// Edits the account's single supplier profile and sends it to the server.
class SupplierProfileDialog extends StatefulWidget {
  const SupplierProfileDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(context: context, builder: (_) => const SupplierProfileDialog());

  @override
  State<SupplierProfileDialog> createState() => _SupplierProfileDialogState();
}

class _SupplierProfileDialogState extends State<SupplierProfileDialog> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final p = context.read<SettingsRepository>().getEffectiveSupplierProfile();
    _c = {
      'name': TextEditingController(text: p.party.name),
      'address1': TextEditingController(text: p.party.addressLine1),
      'address2': TextEditingController(text: p.party.addressLine2),
      'ico': TextEditingController(text: p.party.ico),
      'dic': TextEditingController(text: p.party.dic),
      'phone': TextEditingController(text: p.party.phone),
      'email': TextEditingController(text: p.party.email),
      'bankName': TextEditingController(text: p.bankName),
      'accountNumber': TextEditingController(text: p.accountNumber),
      'bankCode': TextEditingController(text: p.bankCode),
      'iban': TextEditingController(text: p.iban),
      'swift': TextEditingController(text: p.swift),
      'issuerName': TextEditingController(text: p.issuerName),
      'issuerEmail': TextEditingController(text: p.issuerEmail),
      'reportFilename': TextEditingController(text: p.reportFilename),
      'reportRezijniFilename': TextEditingController(text: p.reportRezijniFilename),
      'invoiceFilename': TextEditingController(text: p.invoiceFilename),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(String key) => _c[key]!.text.trim();

  Future<void> _save() async {
    final settings = context.read<SettingsRepository>();
    final sync = context.read<PocketBaseSyncService?>();
    final profile = settings.getEffectiveSupplierProfile().copyWith(
      party: InvoiceParty(name: _v('name'), addressLine1: _v('address1'), addressLine2: _v('address2'), ico: _v('ico'), dic: _v('dic'), phone: _v('phone'), email: _v('email')),
      bankName: _v('bankName'),
      accountNumber: _v('accountNumber'),
      bankCode: _v('bankCode'),
      iban: _v('iban'),
      swift: _v('swift'),
      issuerName: _v('issuerName'),
      issuerEmail: _v('issuerEmail'),
      reportFilename: _v('reportFilename'),
      reportRezijniFilename: _v('reportRezijniFilename'),
      invoiceFilename: _v('invoiceFilename'),
      updatedAt: DateTime.now(),
    );
    await settings.setSupplierProfile(profile);
    if (mounted) Navigator.pop(context);
    await sync?.pushSupplierProfile();
  }

  Widget _field(String key, String labelKey) => TextField(
    controller: _c[key],
    decoration: InputDecoration(labelText: tr(labelKey)),
  );

  Widget _row(List<Widget> fields) => Row(
    children: [
      for (var i = 0; i < fields.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: fields[i])],
    ],
  );

  Widget _section(String titleKey, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(titleKey), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('supplier_profile.title')),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('supplier_profile.hint'), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              _section('pdf_reports.supplier', [
                _field('name', 'pdf_reports.field_name'),
                _field('address1', 'pdf_reports.field_address1'),
                _field('address2', 'pdf_reports.field_address2'),
                _row([_field('ico', 'pdf_reports.field_ico'), _field('dic', 'pdf_reports.field_dic')]),
                _row([_field('phone', 'pdf_reports.field_phone'), _field('email', 'pdf_reports.field_email')]),
              ]),
              _section('pdf_reports.bank_info', [
                _field('bankName', 'pdf_reports.field_bank_name'),
                _row([_field('accountNumber', 'pdf_reports.field_account_number'), _field('bankCode', 'pdf_reports.field_bank_code')]),
                _row([_field('iban', 'supplier_profile.iban'), _field('swift', 'supplier_profile.swift')]),
              ]),
              _section('pdf_reports.issuer_section', [
                _row([_field('issuerName', 'pdf_reports.field_issuer_name'), _field('issuerEmail', 'pdf_reports.field_issuer_email')]),
              ]),
              _section('pdf_reports.files_tab', [
                _field('reportFilename', 'pdf_reports.field_report_filename'),
                _field('reportRezijniFilename', 'pdf_reports.field_report_rezijni_filename'),
                _field('invoiceFilename', 'pdf_reports.field_invoice_filename'),
                Text(tr('pdf_reports.filenames_hint'), style: Theme.of(context).textTheme.bodySmall),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
        FilledButton(onPressed: _save, child: Text(tr('common.save'))),
      ],
    );
  }
}
