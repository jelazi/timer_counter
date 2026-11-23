import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/pdf_report_service.dart';
import '../../core/services/time_invoice_builder.dart';
import '../../data/models/client_model.dart';
import '../../data/models/invoice_settings.dart';
import '../../data/models/project_model.dart';
import '../../data/models/standalone_invoice_model.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/project_client_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/standalone_invoice_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../blocs/standalone_invoice/standalone_invoice_bloc.dart';
import '../blocs/standalone_invoice/standalone_invoice_event.dart';
import '../widgets/app_switch_tile.dart';
import '../widgets/desktop/pane_header.dart';
import '../widgets/invoice_lines_dialog.dart';
import '../widgets/supplier_profile_dialog.dart';

class PdfReportsScreen extends StatefulWidget {
  const PdfReportsScreen({super.key});

  @override
  State<PdfReportsScreen> createState() => _PdfReportsScreenState();
}

class _PdfReportsScreenState extends State<PdfReportsScreen> {
  late int _selectedYear;
  late int _selectedMonth;
  bool _isGenerating = false;
  bool _perProject = false;
  String? _selectedClientId;
  InvoiceLineMode _lineMode = InvoiceLineMode.perProject;
  List<String>? _generatedFiles;
  String? _errorMessage;
  List<String> _selectedProjectIds = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _selectedProjectIds = context.read<SettingsRepository>().getPdfReportProjectIds();
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

  List<ProjectModel> get _activeProjects => context.read<ProjectRepository>().getAll().where((p) => !p.isArchived).toList();

  /// Clients that can be billed for the active projects, each project's top
  /// client first; every active client when no project has one yet.
  List<ClientModel> _billableClients() {
    final clientRepo = context.read<ClientRepository>();
    final linked = context
        .read<ProjectClientRepository>()
        .clientIdsForProjects(_activeProjects.map((p) => p.id))
        .map(clientRepo.getById)
        .whereType<ClientModel>()
        .where((c) => !c.isArchived)
        .toList();
    return linked.isNotEmpty ? linked : clientRepo.getActive();
  }

  ClientModel? _selectedClient() {
    final clients = _billableClients();
    if (clients.isEmpty) return null;
    return clients.firstWhere((c) => c.id == _selectedClientId, orElse: () => clients.first);
  }

  /// Projects on the combined invoice: those linked to [client], or every
  /// active project while the client has no links yet.
  List<String> _invoiceProjectIds(ClientModel? client) {
    final ids = _activeProjects.map((p) => p.id).toList();
    if (client == null) return ids;
    final linked = context.read<ProjectClientRepository>().getByClient(client.id).map((l) => l.projectId).toSet();
    final filtered = ids.where(linked.contains).toList();
    return filtered.isEmpty ? ids : filtered;
  }

  /// The reports cover the invoiced projects; null keeps the "all projects" reports.
  List<String>? _reportProjectIds(List<String> invoiceProjectIds) => invoiceProjectIds.length == _activeProjects.length ? null : invoiceProjectIds;

  String _serviceDescription(String projectId, ClientModel? client) {
    if (client == null) return context.read<SettingsRepository>().getInvoiceSettings().description;
    return context.read<ProjectClientRepository>().find(projectId, client.id)?.serviceDescription ?? '';
  }

  /// Supplier from the profile, customer from [client] (or the old invoice
  /// settings before any client exists), bank details and file names from the profile.
  InvoiceSettings _invoiceSettingsFor(ClientModel? client, List<String> projectIds) {
    final settingsRepo = context.read<SettingsRepository>();
    final profile = settingsRepo.getEffectiveSupplierProfile();
    final legacy = settingsRepo.getInvoiceSettings();
    final descriptions = <String>{for (final id in projectIds) _serviceDescription(id, client)}..remove('');
    return InvoiceSettings(
      supplier: profile.party,
      customer: client?.toInvoiceParty() ?? legacy.customer,
      description: descriptions.join(', '),
      bankName: profile.bankName,
      bankCode: profile.bankCode,
      swift: profile.swift,
      accountNumber: profile.accountNumber,
      iban: profile.iban,
      issuerName: profile.issuerName,
      issuerEmail: profile.issuerEmail,
      reportFilename: profile.reportFilename,
      reportRezijniFilename: profile.reportRezijniFilename,
      invoiceFilename: profile.invoiceFilename,
    );
  }

  InvoiceSettings _loadInvoiceSettings() {
    final client = _selectedClient();
    return _invoiceSettingsFor(client, _invoiceProjectIds(client));
  }

  String _resolveFilename(String pattern) {
    final monthName = _czechMonthsLower[_selectedMonth] ?? '$_selectedMonth';
    return pattern.replaceAll('{month}', monthName).replaceAll('{year}', '$_selectedYear');
  }

  PdfReportService _pdfService() =>
      PdfReportService(timeEntryRepo: context.read<TimeEntryRepository>(), projectRepo: context.read<ProjectRepository>(), taskRepo: context.read<TaskRepository>());

  List<InvoiceLineItem> _proposedLines(PdfReportService service, List<String> projectIds, ClientModel? client, InvoiceLineMode mode) {
    final projectRepo = context.read<ProjectRepository>();
    return TimeInvoiceBuilder.build([
      for (final id in projectIds)
        ProjectBillingLine(
          projectId: id,
          projectName: projectRepo.getById(id)?.name ?? id,
          hours: service.getInvoiceTotals(_monthStart, _monthEnd, projectIds: [id]).totalHours,
          hourlyRate: projectRepo.getById(id)?.hourlyRate ?? 0,
          description: _serviceDescription(id, client),
        ),
    ], mode);
  }

  /// The time-based invoice for this month and client, reusing the number of
  /// one issued before so regenerating overwrites it.
  StandaloneInvoiceModel _draftInvoice({
    required List<String> projectIds,
    required ClientModel? client,
    required InvoiceSettings settings,
    required List<InvoiceLineItem> lines,
    bool singleProject = false,
  }) {
    final invoiceRepo = context.read<StandaloneInvoiceRepository>();
    final existing = invoiceRepo.findTimeBasedInvoice(
      month: _selectedMonth,
      year: _selectedYear,
      projectId: singleProject ? projectIds.first : null,
      clientId: client?.id,
      customerName: settings.customer.name,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return StandaloneInvoiceModel(
      id: existing?.id ?? const Uuid().v4(),
      invoiceNumber: existing?.invoiceNumber ?? invoiceRepo.getNextTimeBasedInvoiceNumber(_selectedMonth),
      issueDate: today,
      dueDate: today.add(const Duration(days: 14)),
      taxDate: DateTime(_selectedYear, _selectedMonth + 1, 0),
      supplierJson: settings.supplier.toJson(),
      customerJson: settings.customer.toJson(),
      lineItems: lines,
      bankName: settings.bankName,
      bankCode: settings.bankCode,
      swift: settings.swift,
      accountNumber: settings.accountNumber,
      iban: settings.iban,
      issuerName: settings.issuerName,
      issuerEmail: settings.issuerEmail,
      notes: 'Auto-generated from PDF Reports for ${_czechMonths[_selectedMonth]} $_selectedYear',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      invoiceType: 'time_based',
      sourceProjectIds: projectIds,
      clientId: client?.id,
    );
  }

  /// Saved through the bloc, so the invoice is also sent to the server.
  void _storeInvoice(StandaloneInvoiceModel invoice) {
    final bloc = context.read<StandaloneInvoiceBloc>();
    final exists = context.read<StandaloneInvoiceRepository>().getById(invoice.id) != null;
    bloc.add(exists ? UpdateStandaloneInvoice(invoice) : AddStandaloneInvoice(invoice));
  }

  Future<bool> _confirmOverwrite(String outputDir, List<String> filenames) async {
    final existingFiles = filenames.where((f) => File('$outputDir/$f').existsSync()).toList();
    if (existingFiles.isEmpty) return true;
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
            for (final f in existingFiles)
              Padding(
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
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('pdf_reports.overwrite_files'))),
        ],
      ),
    );
    return overwrite == true;
  }

  Future<void> _generatePdfs() async {
    final outputDir = await FilePicker.platform.getDirectoryPath(dialogTitle: tr('pdf_reports.select_output_dir'));
    if (outputDir == null || !mounted) return;

    final client = _selectedClient();
    final projectIds = _invoiceProjectIds(client);
    final settings = _invoiceSettingsFor(client, projectIds);
    final filenames = [settings.reportFilename, settings.reportRezijniFilename, settings.invoiceFilename].map((p) => '${_resolveFilename(p)}.pdf').toList();
    if (!await _confirmOverwrite(outputDir, filenames) || !mounted) return;

    final service = _pdfService();
    final lines = await InvoiceLinesDialog.show(context, clientName: settings.customer.name, lines: _proposedLines(service, projectIds, client, _lineMode));
    if (lines == null || !mounted) return;

    setState(() {
      _isGenerating = true;
      _generatedFiles = null;
      _errorMessage = null;
    });

    try {
      final invoice = _draftInvoice(projectIds: projectIds, client: client, settings: settings, lines: lines);
      final paths = await service.writeMonthlyPdfs(_monthStart, _monthEnd, outputDir, settings: settings, invoice: invoice, projectIds: _reportProjectIds(projectIds));
      if (mounted) _storeInvoice(invoice);
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

  /// One invoice per project, each to the client at the top of that project's list.
  Future<void> _generatePdfsPerProject() async {
    final projectRepo = context.read<ProjectRepository>();
    final timeEntryRepo = context.read<TimeEntryRepository>();
    final clientRepo = context.read<ClientRepository>();
    final linkRepo = context.read<ProjectClientRepository>();

    final outputDir = await FilePicker.platform.getDirectoryPath(dialogTitle: tr('pdf_reports.select_output_dir'));
    if (outputDir == null) return;

    final entries = timeEntryRepo.getByDateRange(_monthStart, _monthEnd);
    final projects = (_selectedProjectIds.isEmpty ? _activeProjects : projectRepo.getAll().where((p) => _selectedProjectIds.contains(p.id)))
        .where((project) => entries.any((e) => e.projectId == project.id))
        .toList();
    if (projects.isEmpty || !mounted) return;

    setState(() {
      _isGenerating = true;
      _generatedFiles = null;
      _errorMessage = null;
    });

    try {
      final service = _pdfService();
      final allPaths = <String>[];

      for (final project in projects) {
        final links = linkRepo.getByProject(project.id);
        final client = links.isEmpty ? null : clientRepo.getById(links.first.clientId);
        final settings = _invoiceSettingsFor(client, [project.id]);
        final projectDir = '$outputDir/${project.name}';
        await Directory(projectDir).create(recursive: true);

        final invoice = _draftInvoice(
          projectIds: [project.id],
          client: client,
          settings: settings,
          lines: _proposedLines(service, [project.id], client, InvoiceLineMode.perProject),
          singleProject: true,
        );
        allPaths.addAll(await service.writeMonthlyPdfs(_monthStart, _monthEnd, projectDir, settings: settings, invoice: invoice, projectIds: [project.id]));
        if (mounted) _storeInvoice(invoice);
      }

      setState(() {
        _isGenerating = false;
        _generatedFiles = allPaths;
      });
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _previewPdf(String type, {String? projectId}) async {
    final service = _pdfService();
    final ClientModel? client;
    final List<String> projectIds;
    if (projectId != null) {
      final links = context.read<ProjectClientRepository>().getByProject(projectId);
      client = links.isEmpty ? null : context.read<ClientRepository>().getById(links.first.clientId);
      projectIds = [projectId];
    } else {
      client = _selectedClient();
      projectIds = _perProject && _selectedProjectIds.isNotEmpty ? _selectedProjectIds : _invoiceProjectIds(client);
    }
    final settings = _invoiceSettingsFor(client, projectIds);
    final reportIds = projectId != null ? projectIds : _reportProjectIds(projectIds);

    try {
      Uint8List bytes;
      String filename;

      switch (type) {
        case 'report':
          bytes = await service.generateReportPdf(_monthStart, _monthEnd, moveAnglictina: false, projectIds: reportIds);
          filename = '${_resolveFilename(settings.reportFilename)}.pdf';
          break;
        case 'rezijni':
          bytes = await service.generateReportPdf(_monthStart, _monthEnd, moveAnglictina: true, projectIds: reportIds);
          filename = '${_resolveFilename(settings.reportRezijniFilename)}.pdf';
          break;
        case 'invoice':
          final mode = projectId != null ? InvoiceLineMode.perProject : _lineMode;
          final invoice = _draftInvoice(
            projectIds: projectIds,
            client: client,
            settings: settings,
            lines: _proposedLines(service, projectIds, client, mode),
            singleProject: projectId != null,
          );
          bytes = await service.generateStandaloneInvoicePdf(invoice);
          filename = '${_resolveFilename(settings.invoiceFilename)}.pdf';
          break;
        default:
          return;
      }

      final tempFile = File('${Directory.systemTemp.path}/$filename');
      await tempFile.writeAsBytes(bytes);
      await launchUrl(Uri.file(tempFile.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('pdf_reports.preview_error')}: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildBillingControls(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (_perProject) return Text(tr('pdf_reports.per_project_client_hint'), style: textTheme.bodySmall);

    final clients = _billableClients();
    final selected = _selectedClient();
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (clients.isEmpty)
          Text(tr('pdf_reports.no_client'), style: textTheme.bodySmall)
        else
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<String>(
              key: ValueKey(selected?.id),
              initialValue: selected?.id,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('pdf_reports.client')),
              items: [
                for (final c in clients)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => setState(() => _selectedClientId = id),
            ),
          ),
        SegmentedButton<InvoiceLineMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: InvoiceLineMode.perProject, label: Text(tr('pdf_reports.lines_per_project'))),
            ButtonSegment(value: InvoiceLineMode.single, label: Text(tr('pdf_reports.lines_single'))),
          ],
          selected: {_lineMode},
          onSelectionChanged: (s) => setState(() => _lineMode = s.first),
        ),
      ],
    );
  }

  Widget _buildPerProjectOutputSection(BuildContext context, List allProjects, TimeEntryRepository timeEntryRepo, InvoiceSettings invoiceSettings, PdfReportService pdfService) {
    final monthName = _czechMonthsLower[_selectedMonth] ?? '$_selectedMonth';
    String resolveFilename(String pattern) => pattern.replaceAll('{month}', monthName).replaceAll('{year}', '$_selectedYear');

    final selectedProjects = _selectedProjectIds.isEmpty ? List.from(allProjects) : allProjects.where((p) => _selectedProjectIds.contains(p.id)).toList();
    final projectsWithEntries = selectedProjects.where((project) => timeEntryRepo.getByDateRange(_monthStart, _monthEnd).any((e) => e.projectId == project.id)).toList();

    if (projectsWithEntries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(tr('pdf_reports.no_entries'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.orange)),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Výstup pro každý projekt', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Soubory budou uloženy do podsložek pojmenovaných podle projektu',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 16),

            // Combined preview for all selected projects
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.layers, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Kombinovaný náhled (${projectsWithEntries.length} ${projectsWithEntries.length == 1 ? 'projekt' : projectsWithEntries.length < 5 ? 'projekty' : 'projektů'})',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _FileInfoRow(
                    icon: Icons.table_chart,
                    filename: '${resolveFilename(invoiceSettings.reportFilename)}.pdf',
                    description: tr('pdf_reports.report_desc'),
                    onPreview: () => _previewPdf('report'),
                  ),
                  const SizedBox(height: 4),
                  _FileInfoRow(
                    icon: Icons.table_chart_outlined,
                    filename: '${resolveFilename(invoiceSettings.reportRezijniFilename)}.pdf',
                    description: tr('pdf_reports.report_rezijni_desc'),
                    onPreview: () => _previewPdf('rezijni'),
                  ),
                  const SizedBox(height: 4),
                  _FileInfoRow(
                    icon: Icons.receipt_long,
                    filename: '${resolveFilename(invoiceSettings.invoiceFilename)}.pdf',
                    description: tr('pdf_reports.invoice_desc'),
                    onPreview: () => _previewPdf('invoice'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            for (int idx = 0; idx < projectsWithEntries.length; idx++) ...[
              if (idx > 0) const Divider(height: 24),
              Builder(builder: (ctx) {
                final project = projectsWithEntries[idx];
                final totals = pdfService.getInvoiceTotals(_monthStart, _monthEnd, projectIds: [project.id]);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: Color(project.colorValue), radius: 7),
                        const SizedBox(width: 8),
                        Text(project.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${totals.totalHours.toStringAsFixed(1)} h',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _FileInfoRow(
                      icon: Icons.table_chart,
                      filename: '${project.name}/${resolveFilename(invoiceSettings.reportFilename)}.pdf',
                      description: tr('pdf_reports.report_desc'),
                      onPreview: () => _previewPdf('report', projectId: project.id),
                    ),
                    const SizedBox(height: 4),
                    _FileInfoRow(
                      icon: Icons.table_chart_outlined,
                      filename: '${project.name}/${resolveFilename(invoiceSettings.reportRezijniFilename)}.pdf',
                      description: tr('pdf_reports.report_rezijni_desc'),
                      onPreview: () => _previewPdf('rezijni', projectId: project.id),
                    ),
                    const SizedBox(height: 4),
                    _FileInfoRow(
                      icon: Icons.receipt_long,
                      filename: '${project.name}/${resolveFilename(invoiceSettings.invoiceFilename)}.pdf',
                      description: tr('pdf_reports.invoice_desc'),
                      onPreview: () => _previewPdf('invoice', projectId: project.id),
                    ),
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  String _pluralProjects(int n) {
    if (n == 1) return 'projekt';
    if (n < 5) return 'projekty';
    return 'projektů';
  }

  Widget _buildSummaryCard(
    BuildContext context,
    List allProjects,
    TimeEntryRepository timeEntryRepo,
    PdfReportService pdfService,
    double totalHours,
    int entryCount,
  ) {
    final monthName = DateFormat('MMMM', context.locale.languageCode).format(DateTime(_selectedYear, _selectedMonth));
    final periodLabel = '${monthName[0].toUpperCase()}${monthName.substring(1)} $_selectedYear';

    if (!_perProject) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('pdf_reports.period_summary'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _SummaryTile(icon: Icons.access_time, label: tr('pdf_reports.total_hours'), value: '${totalHours.toStringAsFixed(1)} h', color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 24),
                  _SummaryTile(icon: Icons.list_alt, label: tr('pdf_reports.entries_count'), value: '$entryCount', color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 24),
                  _SummaryTile(icon: Icons.calendar_today, label: tr('pdf_reports.period'), value: periodLabel, color: Theme.of(context).colorScheme.tertiary),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Per-project summary
    final allMonthEntries = timeEntryRepo.getByDateRange(_monthStart, _monthEnd);
    final projectsWithEntries = allProjects.where((p) => allMonthEntries.any((e) => e.projectId == p.id)).toList();
    final allTotals = pdfService.getInvoiceTotals(_monthStart, _monthEnd, projectIds: null);
    final hasSelection = _selectedProjectIds.isNotEmpty;
    final selectedTotals = hasSelection ? pdfService.getInvoiceTotals(_monthStart, _monthEnd, projectIds: _selectedProjectIds) : allTotals;
    final selectedEntryCount = hasSelection
        ? allMonthEntries.where((e) => _selectedProjectIds.contains(e.projectId)).length
        : allMonthEntries.length;
    final allEntryCount = allMonthEntries.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tr('pdf_reports.period_summary'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Text(periodLabel, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onTertiaryContainer, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (projectsWithEntries.isEmpty)
              Text(tr('pdf_reports.no_entries'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.orange))
            else ...[
              // Per-project rows
              ...projectsWithEntries.map((project) {
                final isSelected = !hasSelection || _selectedProjectIds.contains(project.id);
                final t = pdfService.getInvoiceTotals(_monthStart, _monthEnd, projectIds: [project.id]);
                final projectEntryCount = allMonthEntries.where((e) => e.projectId == project.id).length;
                return Opacity(
                  opacity: isSelected ? 1.0 : 0.4,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: Color(project.colorValue), radius: 6),
                        const SizedBox(width: 8),
                        Expanded(child: Text(project.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
                        const SizedBox(width: 16),
                        Text('$projectEntryCount záz.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${t.totalHours.toStringAsFixed(1)} h',
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: isSelected ? Theme.of(context).colorScheme.primary : null),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const Divider(height: 20),
              // Selected total (only when explicit selection exists)
              if (hasSelection) ...[
                Row(
                  children: [
                    Icon(Icons.check_box_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vybrané (${_selectedProjectIds.length} ${_pluralProjects(_selectedProjectIds.length)})',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    Text('$selectedEntryCount záz.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 64,
                      child: Text('${selectedTotals.totalHours.toStringAsFixed(1)} h', textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              // All projects total
              Row(
                children: [
                  Icon(Icons.layers, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Celkem (${projectsWithEntries.length} ${_pluralProjects(projectsWithEntries.length)})',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text('$allEntryCount záz.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 64,
                    child: Text('${allTotals.totalHours.toStringAsFixed(1)} h', textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openInvoiceSettings() async {
    await SupplierProfileDialog.show(context);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final timeEntryRepo = context.read<TimeEntryRepository>();
    final projectRepo = context.read<ProjectRepository>();
    final allProjects = projectRepo.getAll().where((p) => !p.isArchived).toList();
    var entries = timeEntryRepo.getByDateRange(_monthStart, _monthEnd);
    if (_perProject && _selectedProjectIds.isNotEmpty) {
      entries = entries.where((e) => _selectedProjectIds.contains(e.projectId)).toList();
    }
    // Use the same minute-based calculation as the PDF invoice for consistency
    final pdfService = PdfReportService(timeEntryRepo: timeEntryRepo, projectRepo: projectRepo, taskRepo: context.read<TaskRepository>());
    final totals = pdfService.getInvoiceTotals(_monthStart, _monthEnd, projectIds: _perProject && _selectedProjectIds.isNotEmpty ? _selectedProjectIds : null);
    final totalHours = totals.totalHours;
    final entryCount = entries.length;
    final invoiceSettings = _loadInvoiceSettings();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaneHeader(
            title: tr('pdf_reports.title'),
            subtitle: tr('pdf_reports.subtitle'),
            actions: [FilledButton.tonalIcon(onPressed: _openInvoiceSettings, icon: const Icon(Icons.badge_outlined), label: Text(tr('supplier_profile.short')))],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                          initialValue: _selectedMonth,
                                          items: List.generate(12, (i) {
                                            final m = i + 1;
                                            final monthName = DateFormat('MMMM', context.locale.languageCode).format(DateTime(2024, m));
                                            return DropdownMenuItem(value: m, child: Text(monthName[0].toUpperCase() + monthName.substring(1)));
                                          }),
                                          onChanged: (v) => setState(() => _selectedMonth = v!),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      SizedBox(
                                        width: 140,
                                        child: DropdownButtonFormField<int>(
                                          decoration: InputDecoration(labelText: tr('pdf_reports.year'), prefixIcon: const Icon(Icons.date_range), isDense: true),
                                          initialValue: _selectedYear,
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
                          _buildSummaryCard(context, allProjects, timeEntryRepo, pdfService, totalHours, entryCount),
                          const SizedBox(height: 16),

                          // Project filter
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(tr('pdf_reports.project_filter'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                      const Spacer(),
                                      if (_selectedProjectIds.isNotEmpty)
                                        TextButton(
                                          onPressed: () {
                                            setState(() => _selectedProjectIds = []);
                                            context.read<SettingsRepository>().setPdfReportProjectIds([]);
                                          },
                                          child: Text(tr('common.clear')),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedProjectIds.isEmpty ? tr('pdf_reports.all_projects') : tr('pdf_reports.filtered_projects', args: ['${_selectedProjectIds.length}']),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: allProjects.map((project) {
                                      final allSelected = _selectedProjectIds.isEmpty;
                                      final isSelected = allSelected || _selectedProjectIds.contains(project.id);
                                      return FilterChip(
                                        label: Text(project.name),
                                        selected: isSelected,
                                        selectedColor: Color(project.colorValue).withValues(alpha: 0.3),
                                        avatar: CircleAvatar(backgroundColor: Color(project.colorValue), radius: 8),
                                        onSelected: (selected) {
                                          setState(() {
                                            if (allSelected) {
                                              _selectedProjectIds = allProjects.map((p) => p.id).toList();
                                              if (!selected) {
                                                _selectedProjectIds.remove(project.id);
                                              }
                                            } else {
                                              if (selected) {
                                                _selectedProjectIds.add(project.id);
                                              } else {
                                                _selectedProjectIds.remove(project.id);
                                              }
                                              if (_selectedProjectIds.length == allProjects.length) {
                                                _selectedProjectIds = [];
                                              }
                                            }
                                          });
                                          context.read<SettingsRepository>().setPdfReportProjectIds(_selectedProjectIds);
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const Divider(height: 24),
                                  AppSwitchTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Generovat pro každý projekt zvlášť'),
                                    subtitle: const Text('Každý projekt dostane vlastní PDF a fakturu v podsložce'),
                                    value: _perProject,
                                    onChanged: (v) => setState(() => _perProject = v),
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
                                  _buildBillingControls(context),
                                  const SizedBox(height: 16),
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

                          // Output files info — combined or per-project
                          if (!_perProject)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tr('pdf_reports.generated_files'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 12),
                                    _FileInfoRow(
                                      icon: Icons.table_chart,
                                      filename: '${_resolveFilename(invoiceSettings.reportFilename)}.pdf',
                                      description: tr('pdf_reports.report_desc'),
                                      onPreview: entryCount > 0 ? () => _previewPdf('report') : null,
                                    ),
                                    const SizedBox(height: 8),
                                    _FileInfoRow(
                                      icon: Icons.table_chart_outlined,
                                      filename: '${_resolveFilename(invoiceSettings.reportRezijniFilename)}.pdf',
                                      description: tr('pdf_reports.report_rezijni_desc'),
                                      onPreview: entryCount > 0 ? () => _previewPdf('rezijni') : null,
                                    ),
                                    const SizedBox(height: 8),
                                    _FileInfoRow(
                                      icon: Icons.receipt_long,
                                      filename: '${_resolveFilename(invoiceSettings.invoiceFilename)}.pdf',
                                      description: tr('pdf_reports.invoice_desc'),
                                      onPreview: entryCount > 0 ? () => _previewPdf('invoice') : null,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            _buildPerProjectOutputSection(context, allProjects, timeEntryRepo, invoiceSettings, pdfService),
                          const SizedBox(height: 24),

                          // Generate button
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: _isGenerating || entryCount == 0 ? null : (_perProject ? _generatePdfsPerProject : _generatePdfs),
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
          ),
        ],
      ),
    );
  }
}

// ==================== Invoice Settings Dialog ====================

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
  final VoidCallback? onPreview;

  const _FileInfoRow({required this.icon, required this.filename, required this.description, this.onPreview});

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
        if (onPreview != null)
          IconButton(
            onPressed: onPreview,
            icon: const Icon(Icons.visibility),
            tooltip: tr('pdf_reports.preview'),
            style: IconButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
          ),
      ],
    );
  }
}
