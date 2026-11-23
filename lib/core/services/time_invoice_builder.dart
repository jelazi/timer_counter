import '../../data/models/standalone_invoice_model.dart';

/// How the worked hours of several projects appear on one invoice.
enum InvoiceLineMode { perProject, single }

/// Hours worked on one project in the invoiced period, priced at the project's rate.
class ProjectBillingLine {
  final String projectId;
  final String projectName;

  /// Already rounded to one decimal, as printed on the invoice.
  final double hours;
  final double hourlyRate;

  /// The service description of this project for the invoiced client; may be empty.
  final String description;

  const ProjectBillingLine({required this.projectId, required this.projectName, required this.hours, required this.hourlyRate, this.description = ''});

  String get label => description.isNotEmpty ? description : projectName;
}

/// Turns per-project hours into invoice lines.
class TimeInvoiceBuilder {
  TimeInvoiceBuilder._();

  static List<InvoiceLineItem> build(List<ProjectBillingLine> projects, InvoiceLineMode mode) {
    final billed = projects.where((p) => p.hours > 0).toList();
    if (billed.isEmpty) return const [];

    if (mode == InvoiceLineMode.perProject) {
      return [for (final p in billed) InvoiceLineItem(description: p.label, quantity: p.hours, unit: 'hod', unitPrice: p.hourlyRate)];
    }

    final labels = <String>[];
    for (final p in billed) {
      if (!labels.contains(p.label)) labels.add(p.label);
    }
    final description = labels.join(', ');
    final hours = _round1(billed.fold<double>(0, (sum, p) => sum + p.hours));

    final sameRate = billed.every((p) => p.hourlyRate == billed.first.hourlyRate);
    if (sameRate) {
      return [InvoiceLineItem(description: description, quantity: hours, unit: 'hod', unitPrice: billed.first.hourlyRate)];
    }

    // One line cannot be hours × one rate when the rates differ, so it carries
    // the exact sum of the per-project amounts and names the hours in the text.
    final amount = _round2(billed.fold<double>(0, (sum, p) => sum + p.hours * p.hourlyRate));
    final hoursText = hours.toStringAsFixed(1).replaceAll('.', ',');
    return [InvoiceLineItem(description: '$description ($hoursText hod)', quantity: 1, unit: 'ks', unitPrice: amount)];
  }

  static double _round1(double v) => (v * 10).roundToDouble() / 10;

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}
