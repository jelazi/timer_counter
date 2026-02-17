import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/pdf_report_service.dart';
import '../../data/repositories/project_repository.dart';
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

  DateTime get _monthStart => DateTime(_selectedYear, _selectedMonth, 1);
  DateTime get _monthEnd => DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);

  Future<void> _generatePdfs() async {
    // Ask user for output directory
    final outputDir = await FilePicker.platform.getDirectoryPath(dialogTitle: tr('pdf_reports.select_output_dir'));
    if (outputDir == null) return;

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

      final paths = await service.generateAllReports(_monthStart, _monthEnd, outputDir);

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

  @override
  Widget build(BuildContext context) {
    final timeEntryRepo = context.read<TimeEntryRepository>();
    final entries = timeEntryRepo.getByDateRange(_monthStart, _monthEnd);
    final totalSeconds = entries.fold<int>(0, (sum, e) => sum + e.actualDurationSeconds);
    final totalHours = totalSeconds / 3600;
    final entryCount = entries.length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(tr('pdf_reports.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(tr('pdf_reports.subtitle'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 24),

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
                        // Month selector
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
                        // Year selector
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
                        // Quick month navigation
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

            // Output files info
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
                      filename: 'report_${_czechMonths[_selectedMonth]!.toLowerCase()}_$_selectedYear.pdf',
                      description: tr('pdf_reports.report_desc'),
                    ),
                    const SizedBox(height: 8),
                    _FileInfoRow(
                      icon: Icons.table_chart_outlined,
                      filename: 'report_${_czechMonths[_selectedMonth]!.toLowerCase()}_${_selectedYear}_rezijni.pdf',
                      description: tr('pdf_reports.report_rezijni_desc'),
                    ),
                    const SizedBox(height: 8),
                    _FileInfoRow(
                      icon: Icons.receipt_long,
                      filename: 'faktura_${_czechMonths[_selectedMonth]!.toLowerCase()}_$_selectedYear.pdf',
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
          ],
        ),
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
