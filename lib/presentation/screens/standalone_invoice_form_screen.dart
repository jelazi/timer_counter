import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/invoice_settings.dart';
import '../../data/models/standalone_invoice_model.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/standalone_invoice_repository.dart';
import '../blocs/standalone_invoice/standalone_invoice_bloc.dart';
import '../blocs/standalone_invoice/standalone_invoice_event.dart';

class StandaloneInvoiceFormScreen extends StatefulWidget {
  final StandaloneInvoiceModel? invoice;

  const StandaloneInvoiceFormScreen({super.key, this.invoice});

  @override
  State<StandaloneInvoiceFormScreen> createState() => _StandaloneInvoiceFormScreenState();
}

class _StandaloneInvoiceFormScreenState extends State<StandaloneInvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.invoice != null;

  // Invoice header
  late int _invoiceNumber;
  late DateTime _issueDate;
  late DateTime _dueDate;
  late DateTime _taxDate;

  // Supplier
  late TextEditingController _supplierNameCtrl;
  late TextEditingController _supplierAddr1Ctrl;
  late TextEditingController _supplierAddr2Ctrl;
  late TextEditingController _supplierIcoCtrl;
  late TextEditingController _supplierDicCtrl;
  late TextEditingController _supplierPhoneCtrl;
  late TextEditingController _supplierEmailCtrl;

  // Customer
  late TextEditingController _customerNameCtrl;
  late TextEditingController _customerAddr1Ctrl;
  late TextEditingController _customerAddr2Ctrl;
  late TextEditingController _customerIcoCtrl;
  late TextEditingController _customerDicCtrl;

  // Bank
  late TextEditingController _bankNameCtrl;
  late TextEditingController _bankCodeCtrl;
  late TextEditingController _swiftCtrl;
  late TextEditingController _accountNumberCtrl;
  late TextEditingController _ibanCtrl;

  // Issuer
  late TextEditingController _issuerNameCtrl;
  late TextEditingController _issuerEmailCtrl;

  // Notes
  late TextEditingController _notesCtrl;

  // Line items
  late List<_LineItemData> _lineItems;

  @override
  void initState() {
    super.initState();
    final settingsRepo = context.read<SettingsRepository>();
    final invoiceSettings = settingsRepo.getInvoiceSettings();

    if (_isEditing) {
      final inv = widget.invoice!;
      _invoiceNumber = inv.invoiceNumber;
      _issueDate = inv.issueDate;
      _dueDate = inv.dueDate;
      _taxDate = inv.taxDate;

      final supplier = InvoiceParty.fromJson(inv.supplierJson);
      _supplierNameCtrl = TextEditingController(text: supplier.name);
      _supplierAddr1Ctrl = TextEditingController(text: supplier.addressLine1);
      _supplierAddr2Ctrl = TextEditingController(text: supplier.addressLine2);
      _supplierIcoCtrl = TextEditingController(text: supplier.ico);
      _supplierDicCtrl = TextEditingController(text: supplier.dic);
      _supplierPhoneCtrl = TextEditingController(text: supplier.phone);
      _supplierEmailCtrl = TextEditingController(text: supplier.email);

      final customer = InvoiceParty.fromJson(inv.customerJson);
      _customerNameCtrl = TextEditingController(text: customer.name);
      _customerAddr1Ctrl = TextEditingController(text: customer.addressLine1);
      _customerAddr2Ctrl = TextEditingController(text: customer.addressLine2);
      _customerIcoCtrl = TextEditingController(text: customer.ico);
      _customerDicCtrl = TextEditingController(text: customer.dic);

      _bankNameCtrl = TextEditingController(text: inv.bankName);
      _bankCodeCtrl = TextEditingController(text: inv.bankCode);
      _swiftCtrl = TextEditingController(text: inv.swift);
      _accountNumberCtrl = TextEditingController(text: inv.accountNumber);
      _ibanCtrl = TextEditingController(text: inv.iban);

      _issuerNameCtrl = TextEditingController(text: inv.issuerName);
      _issuerEmailCtrl = TextEditingController(text: inv.issuerEmail);

      _notesCtrl = TextEditingController(text: inv.notes);

      _lineItems = inv.lineItems.map((item) => _LineItemData.fromModel(item)).toList();
      if (_lineItems.isEmpty) _lineItems.add(_LineItemData());
    } else {
      final invoiceRepo = context.read<StandaloneInvoiceRepository>();
      _invoiceNumber = invoiceRepo.getNextStandaloneInvoiceNumber();
      _issueDate = DateTime.now();
      _dueDate = DateTime.now().add(const Duration(days: 14));
      _taxDate = DateTime.now();

      _supplierNameCtrl = TextEditingController(text: invoiceSettings.supplier.name);
      _supplierAddr1Ctrl = TextEditingController(text: invoiceSettings.supplier.addressLine1);
      _supplierAddr2Ctrl = TextEditingController(text: invoiceSettings.supplier.addressLine2);
      _supplierIcoCtrl = TextEditingController(text: invoiceSettings.supplier.ico);
      _supplierDicCtrl = TextEditingController(text: invoiceSettings.supplier.dic);
      _supplierPhoneCtrl = TextEditingController(text: invoiceSettings.supplier.phone);
      _supplierEmailCtrl = TextEditingController(text: invoiceSettings.supplier.email);

      _customerNameCtrl = TextEditingController(text: invoiceSettings.customer.name);
      _customerAddr1Ctrl = TextEditingController(text: invoiceSettings.customer.addressLine1);
      _customerAddr2Ctrl = TextEditingController(text: invoiceSettings.customer.addressLine2);
      _customerIcoCtrl = TextEditingController(text: invoiceSettings.customer.ico);
      _customerDicCtrl = TextEditingController(text: invoiceSettings.customer.dic);

      _bankNameCtrl = TextEditingController(text: invoiceSettings.bankName);
      _bankCodeCtrl = TextEditingController(text: invoiceSettings.bankCode);
      _swiftCtrl = TextEditingController(text: invoiceSettings.swift);
      _accountNumberCtrl = TextEditingController(text: invoiceSettings.accountNumber);
      _ibanCtrl = TextEditingController(text: invoiceSettings.iban);

      _issuerNameCtrl = TextEditingController(text: invoiceSettings.issuerName);
      _issuerEmailCtrl = TextEditingController(text: invoiceSettings.issuerEmail);

      _notesCtrl = TextEditingController();

      _lineItems = [_LineItemData()];
    }
  }

  @override
  void dispose() {
    _supplierNameCtrl.dispose();
    _supplierAddr1Ctrl.dispose();
    _supplierAddr2Ctrl.dispose();
    _supplierIcoCtrl.dispose();
    _supplierDicCtrl.dispose();
    _supplierPhoneCtrl.dispose();
    _supplierEmailCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerAddr1Ctrl.dispose();
    _customerAddr2Ctrl.dispose();
    _customerIcoCtrl.dispose();
    _customerDicCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankCodeCtrl.dispose();
    _swiftCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ibanCtrl.dispose();
    _issuerNameCtrl.dispose();
    _issuerEmailCtrl.dispose();
    _notesCtrl.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  InvoiceParty _buildSupplier() => InvoiceParty(
    name: _supplierNameCtrl.text,
    addressLine1: _supplierAddr1Ctrl.text,
    addressLine2: _supplierAddr2Ctrl.text,
    ico: _supplierIcoCtrl.text,
    dic: _supplierDicCtrl.text,
    phone: _supplierPhoneCtrl.text,
    email: _supplierEmailCtrl.text,
  );

  InvoiceParty _buildCustomer() => InvoiceParty(
    name: _customerNameCtrl.text,
    addressLine1: _customerAddr1Ctrl.text,
    addressLine2: _customerAddr2Ctrl.text,
    ico: _customerIcoCtrl.text,
    dic: _customerDicCtrl.text,
  );

  void _saveInvoice() {
    if (!_formKey.currentState!.validate()) return;
    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('standalone_invoices.no_items_error'))));
      return;
    }

    final lineItems = _lineItems.map((item) => item.toModel()).toList();

    final invoice = StandaloneInvoiceModel(
      id: _isEditing ? widget.invoice!.id : const Uuid().v4(),
      invoiceNumber: _invoiceNumber,
      issueDate: _issueDate,
      dueDate: _dueDate,
      taxDate: _taxDate,
      supplierJson: _buildSupplier().toJson(),
      customerJson: _buildCustomer().toJson(),
      lineItems: lineItems,
      bankName: _bankNameCtrl.text,
      bankCode: _bankCodeCtrl.text,
      swift: _swiftCtrl.text,
      accountNumber: _accountNumberCtrl.text,
      iban: _ibanCtrl.text,
      issuerName: _issuerNameCtrl.text,
      issuerEmail: _issuerEmailCtrl.text,
      notes: _notesCtrl.text,
      createdAt: _isEditing ? widget.invoice!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (_isEditing) {
      context.read<StandaloneInvoiceBloc>().add(UpdateStandaloneInvoice(invoice));
    } else {
      context.read<StandaloneInvoiceBloc>().add(AddStandaloneInvoice(invoice));
    }

    Navigator.of(context).pop();
  }

  Future<void> _selectDate(String which) async {
    final initial = which == 'issue'
        ? _issueDate
        : which == 'due'
        ? _dueDate
        : _taxDate;

    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) {
      setState(() {
        switch (which) {
          case 'issue':
            _issueDate = picked;
            break;
          case 'due':
            _dueDate = picked;
            break;
          case 'tax':
            _taxDate = picked;
            break;
        }
      });
    }
  }

  void _addLineItem() {
    setState(() => _lineItems.add(_LineItemData()));
  }

  void _removeLineItem(int index) {
    if (_lineItems.length <= 1) return;
    setState(() {
      _lineItems[index].dispose();
      _lineItems.removeAt(index);
    });
  }

  void _loadSupplierFromSettings() {
    final settingsRepo = context.read<SettingsRepository>();
    final suppliers = settingsRepo.getSuppliers();
    if (suppliers.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('standalone_invoices.select_supplier')),
        children: suppliers
            .map(
              (s) => SimpleDialogOption(
                onPressed: () {
                  setState(() {
                    _supplierNameCtrl.text = s.name;
                    _supplierAddr1Ctrl.text = s.addressLine1;
                    _supplierAddr2Ctrl.text = s.addressLine2;
                    _supplierIcoCtrl.text = s.ico;
                    _supplierDicCtrl.text = s.dic;
                    _supplierPhoneCtrl.text = s.phone;
                    _supplierEmailCtrl.text = s.email;
                  });
                  Navigator.pop(ctx);
                },
                child: Text(s.displayLabel),
              ),
            )
            .toList(),
      ),
    );
  }

  void _loadCustomerFromSettings() {
    final settingsRepo = context.read<SettingsRepository>();
    final customers = settingsRepo.getCustomers();
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('standalone_invoices.no_saved_customers'))));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('standalone_invoices.select_customer')),
        children: customers
            .map(
              (c) => SimpleDialogOption(
                onPressed: () {
                  setState(() {
                    _customerNameCtrl.text = c.name;
                    _customerAddr1Ctrl.text = c.addressLine1;
                    _customerAddr2Ctrl.text = c.addressLine2;
                    _customerIcoCtrl.text = c.ico;
                    _customerDicCtrl.text = c.dic;
                  });
                  Navigator.pop(ctx);
                },
                child: Text(c.displayLabel),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _saveCustomerToGlobal() async {
    final customer = _buildCustomer();
    if (customer.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('standalone_invoices.customer_name_required'))));
      return;
    }
    final settingsRepo = context.read<SettingsRepository>();
    final customers = settingsRepo.getCustomers();
    final existingIdx = customers.indexWhere((c) => c.name == customer.name);
    if (existingIdx >= 0) {
      customers[existingIdx] = customer;
    } else {
      customers.add(customer);
    }
    await settingsRepo.setCustomers(customers);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('standalone_invoices.customer_saved'))));
    }
  }

  double get _totalAmount {
    double total = 0;
    for (final item in _lineItems) {
      final qty = double.tryParse(item.quantityCtrl.text.replaceAll(',', '.')) ?? 0;
      final price = double.tryParse(item.priceCtrl.text.replaceAll(',', '.')) ?? 0;
      final discount = double.tryParse(item.discountCtrl.text.replaceAll(',', '.')) ?? 0;
      final subtotal = qty * price;
      total += subtotal - (subtotal * discount / 100);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? tr('standalone_invoices.edit') : tr('standalone_invoices.create')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(onPressed: _saveInvoice, icon: const Icon(Icons.save), label: Text(tr('common.save'))),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === Invoice Number & Dates ===
              _sectionTitle(tr('standalone_invoices.section_header')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: '$_invoiceNumber',
                              decoration: InputDecoration(labelText: tr('standalone_invoices.invoice_number'), prefixIcon: const Icon(Icons.numbers)),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (v) => _invoiceNumber = int.tryParse(v) ?? _invoiceNumber,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: _dateField(tr('standalone_invoices.issue_date'), dateFmt.format(_issueDate), () => _selectDate('issue'))),
                          const SizedBox(width: 16),
                          Expanded(child: _dateField(tr('standalone_invoices.due_date'), dateFmt.format(_dueDate), () => _selectDate('due'))),
                          const SizedBox(width: 16),
                          Expanded(child: _dateField(tr('standalone_invoices.tax_date'), dateFmt.format(_taxDate), () => _selectDate('tax'))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // === Supplier & Customer side by side ===
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSupplierCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildCustomerCard()),
                ],
              ),
              const SizedBox(height: 16),

              // === Bank & Issuer side by side ===
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildBankCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildIssuerCard()),
                ],
              ),
              const SizedBox(height: 16),

              // === Line Items ===
              _sectionTitle(tr('standalone_invoices.section_items')),
              _buildLineItemsCard(),
              const SizedBox(height: 16),

              // === Total ===
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${tr('standalone_invoices.total')}: ', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        NumberFormat.currency(locale: 'cs', symbol: 'Kč', decimalDigits: 2).format(_totalAmount),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // === Notes ===
              _sectionTitle(tr('standalone_invoices.section_notes')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _notesCtrl,
                    decoration: InputDecoration(labelText: tr('standalone_invoices.notes'), border: const OutlineInputBorder()),
                    maxLines: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
  );

  Widget _dateField(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_today)),
        child: Text(value),
      ),
    );
  }

  Widget _buildSupplierCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tr('standalone_invoices.supplier'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadSupplierFromSettings,
                  icon: const Icon(Icons.person_search, size: 16),
                  label: Text(tr('standalone_invoices.load_saved'), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _supplierNameCtrl,
              decoration: InputDecoration(labelText: tr('standalone_invoices.name'), isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _supplierAddr1Ctrl,
              decoration: InputDecoration(labelText: tr('standalone_invoices.address1'), isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _supplierAddr2Ctrl,
              decoration: InputDecoration(labelText: tr('standalone_invoices.address2'), isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _supplierIcoCtrl,
                    decoration: InputDecoration(labelText: tr('standalone_invoices.ico'), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _supplierDicCtrl,
                    decoration: InputDecoration(labelText: tr('standalone_invoices.dic'), isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _supplierPhoneCtrl,
                    decoration: InputDecoration(labelText: tr('standalone_invoices.phone'), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _supplierEmailCtrl,
                    decoration: InputDecoration(labelText: tr('standalone_invoices.email'), isDense: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tr('standalone_invoices.customer'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _saveCustomerToGlobal,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: Text(tr('standalone_invoices.save_customer'), style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _loadCustomerFromSettings,
                  icon: const Icon(Icons.person_search, size: 16),
                  label: Text(tr('standalone_invoices.load_saved'), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _customerNameCtrl,
              decoration: InputDecoration(labelText: tr('standalone_invoices.name'), isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _customerAddr1Ctrl,
              decoration: InputDecoration(labelText: tr('standalone_invoices.address1'), isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _customerAddr2Ctrl,
              decoration: InputDecoration(labelText: tr('standalone_invoices.address2'), isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customerIcoCtrl,
                    decoration: InputDecoration(labelText: tr('standalone_invoices.ico'), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _customerDicCtrl,
                    decoration: InputDecoration(labelText: tr('standalone_invoices.dic'), isDense: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('standalone_invoices.bank'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bankNameCtrl,
              decoration: InputDecoration(labelText: tr('standalone_invoices.bank_name'), isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _accountNumberCtrl,
                    decoration: InputDecoration(labelText: tr('standalone_invoices.account_number'), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _bankCodeCtrl,
                    decoration: InputDecoration(labelText: tr('standalone_invoices.bank_code'), isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ibanCtrl,
                    decoration: InputDecoration(labelText: 'IBAN', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _swiftCtrl,
                    decoration: InputDecoration(labelText: 'SWIFT', isDense: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('standalone_invoices.issuer'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _issuerNameCtrl,
              decoration: InputDecoration(labelText: tr('standalone_invoices.name'), isDense: true),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _issuerEmailCtrl,
              decoration: InputDecoration(labelText: tr('standalone_invoices.email'), isDense: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(tr('standalone_invoices.item_description'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Text(
                    tr('standalone_invoices.item_quantity'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Text(
                    tr('standalone_invoices.item_unit'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Text(
                    tr('standalone_invoices.item_price'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Text(
                    tr('standalone_invoices.item_discount'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Text(
                    tr('standalone_invoices.item_total'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 40), // space for delete button
              ],
            ),
            const Divider(),

            // Line items
            for (int i = 0; i < _lineItems.length; i++) _buildLineItemRow(i),

            const SizedBox(height: 8),

            // Add button
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: _addLineItem, icon: const Icon(Icons.add_circle_outline), label: Text(tr('standalone_invoices.add_item'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemRow(int index) {
    final item = _lineItems[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: TextFormField(
              controller: item.descriptionCtrl,
              decoration: InputDecoration(hintText: tr('standalone_invoices.item_description_hint'), isDense: true, border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.isEmpty) ? tr('standalone_invoices.required') : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: item.quantityCtrl,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: item.unitCtrl,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: item.priceCtrl,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              controller: item.discountCtrl,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), suffixText: '%'),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              NumberFormat.currency(locale: 'cs', symbol: '', decimalDigits: 2).format(_calcItemTotal(item)),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            width: 40,
            child: _lineItems.length > 1
                ? IconButton(
                    icon: Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.error),
                    onPressed: () => _removeLineItem(index),
                    padding: EdgeInsets.zero,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  double _calcItemTotal(_LineItemData item) {
    final qty = double.tryParse(item.quantityCtrl.text.replaceAll(',', '.')) ?? 0;
    final price = double.tryParse(item.priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final discount = double.tryParse(item.discountCtrl.text.replaceAll(',', '.')) ?? 0;
    final subtotal = qty * price;
    return subtotal - (subtotal * discount / 100);
  }
}

class _LineItemData {
  final TextEditingController descriptionCtrl;
  final TextEditingController quantityCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController discountCtrl;

  _LineItemData({String description = '', double quantity = 1, String unit = 'ks', double unitPrice = 0, double discountPercent = 0})
    : descriptionCtrl = TextEditingController(text: description),
      quantityCtrl = TextEditingController(text: quantity > 0 ? quantity.toString() : '1'),
      unitCtrl = TextEditingController(text: unit),
      priceCtrl = TextEditingController(text: unitPrice > 0 ? unitPrice.toString() : ''),
      discountCtrl = TextEditingController(text: discountPercent > 0 ? discountPercent.toString() : '0');

  factory _LineItemData.fromModel(InvoiceLineItem model) =>
      _LineItemData(description: model.description, quantity: model.quantity, unit: model.unit, unitPrice: model.unitPrice, discountPercent: model.discountPercent);

  InvoiceLineItem toModel() => InvoiceLineItem(
    description: descriptionCtrl.text,
    quantity: double.tryParse(quantityCtrl.text.replaceAll(',', '.')) ?? 1,
    unit: unitCtrl.text,
    unitPrice: double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0,
    discountPercent: double.tryParse(discountCtrl.text.replaceAll(',', '.')) ?? 0,
  );

  void dispose() {
    descriptionCtrl.dispose();
    quantityCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
    discountCtrl.dispose();
  }
}
