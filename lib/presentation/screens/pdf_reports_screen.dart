import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/pdf_report_service.dart';
import '../../data/models/invoice_settings.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';

class PdfReportsScreen extends StatefulWidget {
  const PdfReportsScreen({super.key});

  @override
  State<PdfReportsScreen> createState() => _PdfReportsScreenState();
}

class _PdfReportsScreenState extends State<PdfReportsScreen> {
  late int _selectedYear;
  late int _selectedMonth;
  bool _isGenerating = false;
  List<String>? _generatedFiles;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  static const Map<int, String> _czechMonths = {
    1: 'Leden',
    2: 'Únor',
    3: 'Březen',
    4: 'Duben',
    5: 'Květen',
    6: 'Červen',
    7: 'Červenec',
    8: 'Srpen',
    9: 'Září',
    10: 'Říjen',
    11: 'Listopad',
    12: 'Prosinec',
  };

  static const Map<int, String> _czechMonthsLower = {
    1: 'leden',
    2: 'unor',
    3: 'brezen',
    4: 'duben',
    5: 'kveten',
    6: 'cerven',
    7: 'cervenec',
    8: 'srpen',
    9: 'zari',
    10: 'rijen',
    11: 'listopad',
    12: 'prosinec',
  };

  DateTime get _monthStart => DateTime(_selectedYear, _selectedMonth, 1);
  DateTime get _monthEnd => DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);

  InvoiceSettings _loadInvoiceSettings() {
    final settingsRepo = context.read<SettingsRepository>();
    return settingsRepo.getInvoiceSettings();
  }

  String _resolveFilename(String pattern) {
    final monthName = _czechMonthsLower[_selectedMonth] ?? '$_selectedMonth';
    return pattern.replaceAll('{month}', monthName).replaceAll('{year}', '$_selectedYear');
  }

  Future<void> _generatePdfs() async {
    final outputDir = await FilePicker.platform.getDirectoryPath(dialogTitle: tr('pdf_reports.select_output_dir'));
    if (outputDir == null) return;

    // Check for existing files
    final invoiceSettings = _loadInvoiceSettings();
    final monthName = _czechMonthsLower[_selectedMonth] ?? '$_selectedMonth';
    final filenames = [
      '${invoiceSettings.reportFilename.replaceAll('{month}', monthName).replaceAll('{year}', '$_selectedYear')}.pdf',
      '${invoiceSettings.reportRezijniFilename.replaceAll('{month}', monthName).replaceAll('{year}', '$_selectedYear')}.pdf',
      '${invoiceSettings.invoiceFilename.replaceAll('{month}', monthName).replaceAll('{year}', '$_selectedYear')}.pdf',
    ];
    final existingFiles = filenames.where((f) => File('$outputDir/$f').existsSync()).toList();
    if (existingFiles.isNotEmpty && mounted) {
      final overwrite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
          title: Text(tr('pdf_reports.files_exist_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('pdf_reports.files_exist_desc')),
              const SizedBox(height: 12),
              ...existingFiles.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('common.cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('pdf_reports.overwrite_files'))),
          ],
        ),
      );
      if (overwrite != true) return;
    }

    setState(() {
      _isGenerating = true;
      _generatedFiles = null;
      _errorMessage = null;
    });

    try {
      final service = PdfReportService(
        timeEntryRepo: context.read<TimeEntryRepository>(),
        projectRepo: context.read<ProjectRepository>(),
        taskRepo: context.read<TaskRepository>(),
      );

      final paths = await service.generateAllReports(_monthStart, _monthEnd, outputDir, invoiceSettings: invoiceSettings);

      setState(() {
        _isGenerating = false;
        _generatedFiles = paths;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _openInvoiceSettings() {
    final settingsRepo = context.read<SettingsRepository>();
    showDialog(
      context: context,
      builder: (ctx) => _InvoiceSettingsDialog(settingsRepo: settingsRepo),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final timeEntryRepo = context.read<TimeEntryRepository>();
    final entries = timeEntryRepo.getByDateRange(_monthStart, _monthEnd);
    final totalSeconds = entries.fold<int>(0, (sum, e) => sum + e.actualDurationSeconds);
    final totalHours = totalSeconds / 3600;
    final entryCount = entries.length;
    final invoiceSettings = _loadInvoiceSettings();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('pdf_reports.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        tr('pdf_reports.subtitle'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(onPressed: _openInvoiceSettings, icon: const Icon(Icons.settings), label: Text(tr('pdf_reports.invoice_settings'))),
              ],
            ),
            const SizedBox(height: 16),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month/Year selection card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('pdf_reports.select_period'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                SizedBox(
                                  width: 200,
                                  child: DropdownButtonFormField<int>(
                                    decoration: InputDecoration(labelText: tr('pdf_reports.month'), prefixIcon: const Icon(Icons.calendar_month), isDense: true),
                                    value: _selectedMonth,
                                    items: List.generate(12, (i) {
                                      final m = i + 1;
                                      return DropdownMenuItem(value: m, child: Text(_czechMonths[m]!));
                                    }),
                                    onChanged: (v) => setState(() => _selectedMonth = v!),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 140,
                                  child: DropdownButtonFormField<int>(
                                    decoration: InputDecoration(labelText: tr('pdf_reports.year'), prefixIcon: const Icon(Icons.date_range), isDense: true),
                                    value: _selectedYear,
                                    items: List.generate(7, (i) {
                                      final y = DateTime.now().year - 3 + i;
                                      return DropdownMenuItem(value: y, child: Text('$y'));
                                    }),
                                    onChanged: (v) => setState(() => _selectedYear = v!),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_selectedMonth > 1) {
                                        _selectedMonth--;
                                      } else {
                                        _selectedMonth = 12;
                                        _selectedYear--;
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.chevron_left),
                                  tooltip: tr('pdf_reports.previous_month'),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_selectedMonth < 12) {
                                        _selectedMonth++;
                                      } else {
                                        _selectedMonth = 1;
                                        _selectedYear++;
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.chevron_right),
                                  tooltip: tr('pdf_reports.next_month'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Period summary card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('pdf_reports.period_summary'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _SummaryTile(
                                  icon: Icons.access_time,
                                  label: tr('pdf_reports.total_hours'),
                                  value: '${totalHours.toStringAsFixed(1)} h',
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 24),
                                _SummaryTile(icon: Icons.list_alt, label: tr('pdf_reports.entries_count'), value: '$entryCount', color: Theme.of(context).colorScheme.secondary),
                                const SizedBox(width: 24),
                                _SummaryTile(
                                  icon: Icons.calendar_today,
                                  label: tr('pdf_reports.period'),
                                  value: '${_czechMonths[_selectedMonth]} $_selectedYear',
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Invoice info summary
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(tr('pdf_reports.invoice_info'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                const Spacer(),
                                TextButton.icon(onPressed: _openInvoiceSettings, icon: const Icon(Icons.edit, size: 16), label: Text(tr('pdf_reports.edit'))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Supplier
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(tr('pdf_reports.supplier'), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(invoiceSettings.supplier.name, style: Theme.of(context).textTheme.bodySmall),
                                      Text(invoiceSettings.supplier.addressLine1, style: Theme.of(context).textTheme.bodySmall),
                                      Text(invoiceSettings.supplier.addressLine2, style: Theme.of(context).textTheme.bodySmall),
                                      if (invoiceSettings.supplier.ico.isNotEmpty) Text('IČO: ${invoiceSettings.supplier.ico}', style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                // Customer
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(tr('pdf_reports.customer'), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(invoiceSettings.customer.name, style: Theme.of(context).textTheme.bodySmall),
                                      Text(invoiceSettings.customer.addressLine1, style: Theme.of(context).textTheme.bodySmall),
                                      Text(invoiceSettings.customer.addressLine2, style: Theme.of(context).textTheme.bodySmall),
                                      if (invoiceSettings.customer.ico.isNotEmpty) Text('IČO: ${invoiceSettings.customer.ico}', style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                // Bank & description
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(tr('pdf_reports.description_label'), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(invoiceSettings.description, style: Theme.of(context).textTheme.bodySmall),
                                      const SizedBox(height: 8),
                                      Text(tr('pdf_reports.bank_info'), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('${invoiceSettings.accountNumber} / ${invoiceSettings.bankCode}', style: Theme.of(context).textTheme.bodySmall),
                                      if (invoiceSettings.iban.isNotEmpty) Text('IBAN: ${invoiceSettings.iban}', style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Output files info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('pdf_reports.generated_files'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            _FileInfoRow(icon: Icons.table_chart, filename: '${_resolveFilename(invoiceSettings.reportFilename)}.pdf', description: tr('pdf_reports.report_desc')),
                            const SizedBox(height: 8),
                            _FileInfoRow(
                              icon: Icons.table_chart_outlined,
                              filename: '${_resolveFilename(invoiceSettings.reportRezijniFilename)}.pdf',
                              description: tr('pdf_reports.report_rezijni_desc'),
                            ),
                            const SizedBox(height: 8),
                            _FileInfoRow(
                              icon: Icons.receipt_long,
                              filename: '${_resolveFilename(invoiceSettings.invoiceFilename)}.pdf',
                              description: tr('pdf_reports.invoice_desc'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Generate button
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: _isGenerating || entryCount == 0 ? null : _generatePdfs,
                          icon: _isGenerating
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.picture_as_pdf),
                          label: Text(_isGenerating ? tr('pdf_reports.generating') : tr('pdf_reports.generate')),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                        ),
                        if (entryCount == 0) ...[
                          const SizedBox(width: 16),
                          Text(tr('pdf_reports.no_entries'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.orange)),
                        ],
                      ],
                    ),

                    // Results
                    if (_generatedFiles != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text(
                                    tr('pdf_reports.success'),
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ..._generatedFiles!.map(
                                (path) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(path, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green.shade700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_errorMessage!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red.shade700)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Invoice Settings Dialog ====================

class _InvoiceSettingsDialog extends StatefulWidget {
  final SettingsRepository settingsRepo;

  const _InvoiceSettingsDialog({required this.settingsRepo});

  @override
  State<_InvoiceSettingsDialog> createState() => _InvoiceSettingsDialogState();
}

class _InvoiceSettingsDialogState extends State<_InvoiceSettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Supplier fields
  late TextEditingController _supplierName;
  late TextEditingController _supplierAddress1;
  late TextEditingController _supplierAddress2;
  late TextEditingController _supplierIco;
  late TextEditingController _supplierPhone;
  late TextEditingController _supplierEmail;

  // Customer fields
  late TextEditingController _customerName;
  late TextEditingController _customerAddress1;
  late TextEditingController _customerAddress2;
  late TextEditingController _customerIco;
  late TextEditingController _customerDic;

  // Bank fields
  late TextEditingController _bankName;
  late TextEditingController _bankCode;
  late TextEditingController _swift;
  late TextEditingController _accountNumber;
  late TextEditingController _iban;

  // Other fields
  late TextEditingController _description;
  late TextEditingController _issuerName;
  late TextEditingController _issuerEmail;
  late TextEditingController _reportFilename;
  late TextEditingController _reportRezijniFilename;
  late TextEditingController _invoiceFilename;

  List<InvoiceParty> _suppliers = [];
  List<InvoiceParty> _customers = [];
  int _selectedSupplierIdx = -1;
  int _selectedCustomerIdx = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    final s = widget.settingsRepo;
    final settings = s.getInvoiceSettings();

    _suppliers = s.getSuppliers();
    _customers = s.getCustomers();
    _selectedSupplierIdx = s.getSelectedSupplierIndex();
    _selectedCustomerIdx = s.getSelectedCustomerIndex();

    _supplierName = TextEditingController(text: settings.supplier.name);
    _supplierAddress1 = TextEditingController(text: settings.supplier.addressLine1);
    _supplierAddress2 = TextEditingController(text: settings.supplier.addressLine2);
    _supplierIco = TextEditingController(text: settings.supplier.ico);
    _supplierPhone = TextEditingController(text: settings.supplier.phone);
    _supplierEmail = TextEditingController(text: settings.supplier.email);

    _customerName = TextEditingController(text: settings.customer.name);
    _customerAddress1 = TextEditingController(text: settings.customer.addressLine1);
    _customerAddress2 = TextEditingController(text: settings.customer.addressLine2);
    _customerIco = TextEditingController(text: settings.customer.ico);
    _customerDic = TextEditingController(text: settings.customer.dic);

    _bankName = TextEditingController(text: settings.bankName);
    _bankCode = TextEditingController(text: settings.bankCode);
    _swift = TextEditingController(text: settings.swift);
    _accountNumber = TextEditingController(text: settings.accountNumber);
    _iban = TextEditingController(text: settings.iban);

    _description = TextEditingController(text: settings.description);
    _issuerName = TextEditingController(text: settings.issuerName);
    _issuerEmail = TextEditingController(text: settings.issuerEmail);
    _reportFilename = TextEditingController(text: settings.reportFilename);
    _reportRezijniFilename = TextEditingController(text: settings.reportRezijniFilename);
    _invoiceFilename = TextEditingController(text: settings.invoiceFilename);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _supplierName.dispose();
    _supplierAddress1.dispose();
    _supplierAddress2.dispose();
    _supplierIco.dispose();
    _supplierPhone.dispose();
    _supplierEmail.dispose();
    _customerName.dispose();
    _customerAddress1.dispose();
    _customerAddress2.dispose();
    _customerIco.dispose();
    _customerDic.dispose();
    _bankName.dispose();
    _bankCode.dispose();
    _swift.dispose();
    _accountNumber.dispose();
    _iban.dispose();
    _description.dispose();
    _issuerName.dispose();
    _issuerEmail.dispose();
    _reportFilename.dispose();
    _reportRezijniFilename.dispose();
    _invoiceFilename.dispose();
    super.dispose();
  }

  InvoiceParty _currentSupplier() => InvoiceParty(
    name: _supplierName.text,
    addressLine1: _supplierAddress1.text,
    addressLine2: _supplierAddress2.text,
    ico: _supplierIco.text,
    phone: _supplierPhone.text,
    email: _supplierEmail.text,
  );

  InvoiceParty _currentCustomer() =>
      InvoiceParty(name: _customerName.text, addressLine1: _customerAddress1.text, addressLine2: _customerAddress2.text, ico: _customerIco.text, dic: _customerDic.text);

  void _loadSupplierFields(InvoiceParty party) {
    _supplierName.text = party.name;
    _supplierAddress1.text = party.addressLine1;
    _supplierAddress2.text = party.addressLine2;
    _supplierIco.text = party.ico;
    _supplierPhone.text = party.phone;
    _supplierEmail.text = party.email;
  }

  void _loadCustomerFields(InvoiceParty party) {
    _customerName.text = party.name;
    _customerAddress1.text = party.addressLine1;
    _customerAddress2.text = party.addressLine2;
    _customerIco.text = party.ico;
    _customerDic.text = party.dic;
  }

  Future<void> _saveSupplierToList() async {
    final party = _currentSupplier();
    if (party.name.isEmpty) return;
    // Check if already exists by name
    final existingIdx = _suppliers.indexWhere((s) => s.name == party.name);
    if (existingIdx >= 0) {
      _suppliers[existingIdx] = party;
    } else {
      _suppliers.add(party);
    }
    await widget.settingsRepo.setSuppliers(_suppliers);
    setState(() {});
  }

  Future<void> _saveCustomerToList() async {
    final party = _currentCustomer();
    if (party.name.isEmpty) return;
    final existingIdx = _customers.indexWhere((c) => c.name == party.name);
    if (existingIdx >= 0) {
      _customers[existingIdx] = party;
    } else {
      _customers.add(party);
    }
    await widget.settingsRepo.setCustomers(_customers);
    setState(() {});
  }

  Future<void> _save() async {
    final s = widget.settingsRepo;

    // Save supplier/customer to list if not empty
    await _saveSupplierToList();
    await _saveCustomerToList();

    // Find and set selected indices
    final supplier = _currentSupplier();
    final customer = _currentCustomer();
    final sIdx = _suppliers.indexWhere((p) => p.name == supplier.name);
    final cIdx = _customers.indexWhere((p) => p.name == customer.name);
    await s.setSelectedSupplierIndex(sIdx);
    await s.setSelectedCustomerIndex(cIdx);

    // Save all other settings
    await s.setInvoiceDescription(_description.text);
    await s.setInvoiceBankName(_bankName.text);
    await s.setInvoiceBankCode(_bankCode.text);
    await s.setInvoiceSwift(_swift.text);
    await s.setInvoiceAccountNumber(_accountNumber.text);
    await s.setInvoiceIban(_iban.text);
    await s.setInvoiceIssuerName(_issuerName.text);
    await s.setInvoiceIssuerEmail(_issuerEmail.text);
    await s.setInvoiceReportFilename(_reportFilename.text);
    await s.setInvoiceReportRezijniFilename(_reportRezijniFilename.text);
    await s.setInvoiceInvoiceFilename(_invoiceFilename.text);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long),
                  const SizedBox(width: 12),
                  Text(tr('pdf_reports.invoice_settings'), style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            // Tabs
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: tr('pdf_reports.supplier')),
                Tab(text: tr('pdf_reports.customer')),
                Tab(text: tr('pdf_reports.bank_tab')),
                Tab(text: tr('pdf_reports.invoice_tab')),
                Tab(text: tr('pdf_reports.files_tab')),
              ],
            ),
            // Tab content
            Expanded(
              child: TabBarView(controller: _tabController, children: [_buildSupplierTab(), _buildCustomerTab(), _buildBankTab(), _buildInvoiceTab(), _buildFilesTab()]),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
                  const SizedBox(width: 12),
                  FilledButton(onPressed: _save, child: Text(tr('common.save'))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Saved suppliers list
          if (_suppliers.isNotEmpty) ...[
            Text(tr('pdf_reports.saved_suppliers'), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (int i = 0; i < _suppliers.length; i++)
                  InputChip(
                    label: Text(_suppliers[i].displayLabel),
                    selected: _selectedSupplierIdx == i,
                    onSelected: (selected) {
                      if (selected) {
                        _loadSupplierFields(_suppliers[i]);
                        setState(() => _selectedSupplierIdx = i);
                      }
                    },
                    onDeleted: () async {
                      await widget.settingsRepo.removeSupplierAt(i);
                      setState(() {
                        _suppliers.removeAt(i);
                        if (_selectedSupplierIdx == i) _selectedSupplierIdx = -1;
                        if (_selectedSupplierIdx > i) _selectedSupplierIdx--;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // Form fields
          _buildField(_supplierName, tr('pdf_reports.field_name')),
          _buildField(_supplierAddress1, tr('pdf_reports.field_address1')),
          _buildField(_supplierAddress2, tr('pdf_reports.field_address2')),
          Row(
            children: [
              Expanded(child: _buildField(_supplierIco, tr('pdf_reports.field_ico'))),
              const SizedBox(width: 16),
              Expanded(child: _buildField(_supplierPhone, tr('pdf_reports.field_phone'))),
            ],
          ),
          _buildField(_supplierEmail, tr('pdf_reports.field_email')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await _saveSupplierToList();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('pdf_reports.supplier_saved'))));
            },
            icon: const Icon(Icons.save, size: 16),
            label: Text(tr('pdf_reports.save_to_list')),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_customers.isNotEmpty) ...[
            Text(tr('pdf_reports.saved_customers'), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (int i = 0; i < _customers.length; i++)
                  InputChip(
                    label: Text(_customers[i].displayLabel),
                    selected: _selectedCustomerIdx == i,
                    onSelected: (selected) {
                      if (selected) {
                        _loadCustomerFields(_customers[i]);
                        setState(() => _selectedCustomerIdx = i);
                      }
                    },
                    onDeleted: () async {
                      await widget.settingsRepo.removeCustomerAt(i);
                      setState(() {
                        _customers.removeAt(i);
                        if (_selectedCustomerIdx == i) _selectedCustomerIdx = -1;
                        if (_selectedCustomerIdx > i) _selectedCustomerIdx--;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _buildField(_customerName, tr('pdf_reports.field_name')),
          _buildField(_customerAddress1, tr('pdf_reports.field_address1')),
          _buildField(_customerAddress2, tr('pdf_reports.field_address2')),
          Row(
            children: [
              Expanded(child: _buildField(_customerIco, tr('pdf_reports.field_ico'))),
              const SizedBox(width: 16),
              Expanded(child: _buildField(_customerDic, tr('pdf_reports.field_dic'))),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await _saveCustomerToList();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('pdf_reports.customer_saved'))));
            },
            icon: const Icon(Icons.save, size: 16),
            label: Text(tr('pdf_reports.save_to_list')),
          ),
        ],
      ),
    );
  }

  Widget _buildBankTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField(_bankName, tr('pdf_reports.field_bank_name')),
          Row(
            children: [
              Expanded(child: _buildField(_accountNumber, tr('pdf_reports.field_account_number'))),
              const SizedBox(width: 16),
              Expanded(child: _buildField(_bankCode, tr('pdf_reports.field_bank_code'))),
            ],
          ),
          _buildField(_iban, 'IBAN'),
          _buildField(_swift, 'SWIFT'),
        ],
      ),
    );
  }

  Widget _buildInvoiceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('pdf_reports.description_label'), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _buildField(_description, tr('pdf_reports.field_description')),
          const Divider(height: 32),
          Text(tr('pdf_reports.issuer_section'), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _buildField(_issuerName, tr('pdf_reports.field_issuer_name')),
          _buildField(_issuerEmail, tr('pdf_reports.field_issuer_email')),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('pdf_reports.filenames_hint'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 16),
          _buildField(_reportFilename, tr('pdf_reports.field_report_filename')),
          _buildField(_reportRezijniFilename, tr('pdf_reports.field_report_rezijni_filename')),
          _buildField(_invoiceFilename, tr('pdf_reports.field_invoice_filename')),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 2),
            Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class _FileInfoRow extends StatelessWidget {
  final IconData icon;
  final String filename;
  final String description;

  const _FileInfoRow({required this.icon, required this.filename, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(filename, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ],
    );
  }
}
