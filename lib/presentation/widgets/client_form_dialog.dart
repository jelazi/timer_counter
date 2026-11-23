import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/client_model.dart';

/// Create or edit a client. Returns the saved [ClientModel], or null when cancelled.
class ClientFormDialog extends StatefulWidget {
  final ClientModel? client;

  const ClientFormDialog({super.key, this.client});

  static Future<ClientModel?> show(BuildContext context, {ClientModel? client}) => showDialog<ClientModel>(
    context: context,
    builder: (_) => ClientFormDialog(client: client),
  );

  @override
  State<ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _ico;
  late final TextEditingController _dic;
  late final TextEditingController _address1;
  late final TextEditingController _address2;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _name = TextEditingController(text: c?.name ?? '');
    _ico = TextEditingController(text: c?.ico ?? '');
    _dic = TextEditingController(text: c?.dic ?? '');
    _address1 = TextEditingController(text: c?.addressLine1 ?? '');
    _address2 = TextEditingController(text: c?.addressLine2 ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _ico, _dic, _address1, _address2, _email, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final base = widget.client ?? ClientModel(id: const Uuid().v4(), name: '', createdAt: DateTime.now());
    Navigator.pop(
      context,
      base.copyWith(
        name: _name.text.trim(),
        ico: _ico.text.trim(),
        dic: _dic.text.trim(),
        addressLine1: _address1.text.trim(),
        addressLine2: _address2.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
  }

  Widget _field(TextEditingController controller, String labelKey, {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: tr(labelKey)),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? tr('clients.name_required') : null : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 10);
    return AlertDialog(
      title: Text(tr(widget.client == null ? 'clients.add' : 'clients.edit')),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'clients.name', required: true),
                gap,
                Row(
                  children: [
                    Expanded(child: _field(_ico, 'clients.ico')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_dic, 'clients.dic')),
                  ],
                ),
                gap,
                _field(_address1, 'clients.address1'),
                gap,
                _field(_address2, 'clients.address2'),
                gap,
                Row(
                  children: [
                    Expanded(child: _field(_email, 'clients.email')),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_phone, 'clients.phone')),
                  ],
                ),
                gap,
                _field(_notes, 'clients.notes', maxLines: 3),
              ],
            ),
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
