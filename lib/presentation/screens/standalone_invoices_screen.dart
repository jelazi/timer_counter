import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/pdf_report_service.dart';
import '../../data/models/standalone_invoice_model.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../blocs/standalone_invoice/standalone_invoice_bloc.dart';
import '../blocs/standalone_invoice/standalone_invoice_event.dart';
import '../blocs/standalone_invoice/standalone_invoice_state.dart';
import 'standalone_invoice_form_screen.dart';

class StandaloneInvoicesScreen extends StatelessWidget {
  const StandaloneInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StandaloneInvoiceBloc, StandaloneInvoiceState>(
      builder: (context, state) {
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
                          Text(tr('standalone_invoices.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            tr('standalone_invoices.subtitle'),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                    if (state is StandaloneInvoiceLoaded)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Chip(
                          avatar: const Icon(Icons.numbers, size: 16),
                          label: Text('${tr('standalone_invoices.next_number')}: ${state.nextInvoiceNumber}', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    FilledButton.icon(onPressed: () => _openCreateInvoice(context), icon: const Icon(Icons.add), label: Text(tr('standalone_invoices.create'))),
                  ],
                ),
                const SizedBox(height: 16),
                // Content
                Expanded(child: _buildContent(context, state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, StandaloneInvoiceState state) {
    if (state is StandaloneInvoiceLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is StandaloneInvoiceError) {
      return Center(
        child: Text(state.message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }
    if (state is StandaloneInvoiceLoaded) {
      if (state.invoices.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(tr('standalone_invoices.empty'), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: 8),
              Text(
                tr('standalone_invoices.empty_hint'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
        );
      }
      return _buildInvoiceList(context, state.invoices);
    }
    return const SizedBox.shrink();
  }

  Widget _buildInvoiceList(BuildContext context, List<StandaloneInvoiceModel> invoices) {
    return ListView.builder(
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        final totalFormatted = NumberFormat.currency(locale: 'cs', symbol: 'Kč', decimalDigits: 2).format(invoice.totalAmount);
        final dateFormatted = DateFormat('dd.MM.yyyy').format(invoice.issueDate);
        final customer = invoice.customerJson['name'] as String? ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                '${invoice.invoiceNumber}',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            title: Row(
              children: [
                Text(invoice.invoiceNumberFormatted, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (invoice.isTimeBased)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(4)),
                    child: Text(tr('standalone_invoices.type_time_based'), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onTertiaryContainer)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)),
                    child: Text(tr('standalone_invoices.type_standalone'), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSecondaryContainer)),
                  ),
                const SizedBox(width: 8),
                if (invoice.lineItems.isNotEmpty)
                  Expanded(
                    child: Text(invoice.lineItems.first.description, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                  ),
              ],
            ),
            subtitle: Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(dateFormatted, style: Theme.of(context).textTheme.bodySmall),
                if (customer.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.business, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(customer, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(totalFormatted, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.picture_as_pdf, size: 20), tooltip: tr('standalone_invoices.preview_pdf'), onPressed: () => _previewPdf(context, invoice)),
                if (invoice.isStandalone) ...[
                  IconButton(icon: const Icon(Icons.save_alt, size: 20), tooltip: tr('standalone_invoices.export_pdf'), onPressed: () => _exportPdf(context, invoice)),
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 20), tooltip: tr('common.edit'), onPressed: () => _openEditInvoice(context, invoice)),
                ],
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: Theme.of(context).colorScheme.error),
                  tooltip: tr('common.delete'),
                  onPressed: () => _deleteInvoice(context, invoice),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCreateInvoice(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const StandaloneInvoiceFormScreen()));
  }

  void _openEditInvoice(BuildContext context, StandaloneInvoiceModel invoice) {
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => StandaloneInvoiceFormScreen(invoice: invoice)));
  }

  Future<void> _deleteInvoice(BuildContext context, StandaloneInvoiceModel invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error, size: 36),
        title: Text(tr('standalone_invoices.delete_title')),
        content: Text(tr('standalone_invoices.delete_confirm', namedArgs: {'number': invoice.invoiceNumberFormatted})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<StandaloneInvoiceBloc>().add(DeleteStandaloneInvoice(invoice.id));
    }
  }

  Future<void> _previewPdf(BuildContext context, StandaloneInvoiceModel invoice) async {
    try {
      final service = PdfReportService(
        timeEntryRepo: context.read<TimeEntryRepository>(),
        projectRepo: context.read<ProjectRepository>(),
        taskRepo: context.read<TaskRepository>(),
      );
      final bytes = await service.generateStandaloneInvoicePdf(invoice);
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/faktura_${invoice.invoiceNumberFormatted}.pdf');
      await tempFile.writeAsBytes(bytes);
      await launchUrl(Uri.file(tempFile.path));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('standalone_invoices.pdf_error')}: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _exportPdf(BuildContext context, StandaloneInvoiceModel invoice) async {
    try {
      final outputDir = await FilePicker.platform.getDirectoryPath(dialogTitle: tr('standalone_invoices.select_output_dir'));
      if (outputDir == null) return;

      final service = PdfReportService(
        timeEntryRepo: context.read<TimeEntryRepository>(),
        projectRepo: context.read<ProjectRepository>(),
        taskRepo: context.read<TaskRepository>(),
      );
      final bytes = await service.generateStandaloneInvoicePdf(invoice);
      final filename = 'faktura_${invoice.invoiceNumberFormatted}.pdf';
      final file = File('$outputDir/$filename');
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('standalone_invoices.pdf_saved')}: $filename'),
            action: SnackBarAction(label: tr('common.open'), onPressed: () => launchUrl(Uri.file(file.path))),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('standalone_invoices.pdf_error')}: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
