import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/invoice_settings.dart';
import '../../data/models/standalone_invoice_model.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';

/// Service to generate PDF reports matching the Python json_to_pdf script output.
class PdfReportService {
  final TimeEntryRepository timeEntryRepo;
  final ProjectRepository projectRepo;
  final TaskRepository taskRepo;

  PdfReportService({required this.timeEntryRepo, required this.projectRepo, required this.taskRepo});

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

  String _minutesToHHMM(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Load Inter fonts from assets
  Future<({pw.Font regular, pw.Font bold})> _loadFonts() async {
    final regularData = await rootBundle.load('assets/fonts/Inter-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Inter-Bold.ttf');
    return (regular: pw.Font.ttf(regularData), bold: pw.Font.ttf(boldData));
  }

  /// Process time entries for a given month and return structured data.
  /// If [moveAnglictina] is true, entries with task name "Angličtina" are merged into "Režijní čas".
  _ReportData _processEntries(DateTime monthStart, DateTime monthEnd, {bool moveAnglictina = false, List<String>? projectIds}) {
    var entries = timeEntryRepo.getByDateRange(monthStart, monthEnd);
    if (projectIds != null && projectIds.isNotEmpty) {
      entries = entries.where((e) => projectIds.contains(e.projectId)).toList();
    }
    final year = monthStart.year;
    final month = monthStart.month;

    // day -> taskName -> totalMinutes
    final Map<int, Map<String, int>> dayTaskMinutes = {};
    final Set<String> allTasks = {};

    for (final entry in entries) {
      final day = entry.startTime.day;
      final task = taskRepo.getById(entry.taskId);
      String taskName = task?.name ?? 'Unknown';

      if (moveAnglictina && taskName == 'Angličtina') {
        taskName = 'Režijní čas';
      }

      dayTaskMinutes.putIfAbsent(day, () => {});
      dayTaskMinutes[day]!.putIfAbsent(taskName, () => 0);
      dayTaskMinutes[day]![taskName] = dayTaskMinutes[day]![taskName]! + (entry.actualDurationSeconds ~/ 60);
      allTasks.add(taskName);
    }

    // Sort tasks: priority order first, then alphabetically
    final priorityOrder = ['Angličtina', 'Režijní čas', 'Porady, meetingy'];
    final sortedTasks = <String>[];
    for (final pt in priorityOrder) {
      if (allTasks.contains(pt)) sortedTasks.add(pt);
    }
    final remaining = allTasks.where((t) => !priorityOrder.contains(t)).toList()..sort();
    sortedTasks.addAll(remaining);

    // Get hourly rate from first project that has entries in this period
    double hourlyRate = 550;
    if (entries.isNotEmpty) {
      final project = projectRepo.getById(entries.first.projectId);
      if (project != null && project.hourlyRate > 0) {
        hourlyRate = project.hourlyRate;
      }
    }

    return _ReportData(year: year, month: month, dayTaskMinutes: dayTaskMinutes, sortedTasks: sortedTasks, hourlyRate: hourlyRate);
  }

  /// Generate the monthly report PDF (table with days x tasks).
  Future<Uint8List> generateReportPdf(DateTime monthStart, DateTime monthEnd, {bool moveAnglictina = false, List<String>? projectIds}) async {
    final fonts = await _loadFonts();
    final data = _processEntries(monthStart, monthEnd, moveAnglictina: moveAnglictina, projectIds: projectIds);
    final numDays = DateTime(data.year, data.month + 1, 0).day;
    final monthName = _czechMonths[data.month] ?? '${data.month}';

    final pdf = pw.Document();

    // Colors matching the Python script
    const headerBg = PdfColor.fromInt(0xFF4472C4);
    const dayColBg = PdfColor.fromInt(0xFFD9E1F2);
    const totalColBg = PdfColor.fromInt(0xFFE2EFDA);
    const totalRowBg = PdfColor.fromInt(0xFF70AD47);
    const altRowBg = PdfColor.fromInt(0xFFF2F2F2);

    // Build table data
    final allTasks = data.sortedTasks;
    final numCols = 1 + allTasks.length + 1; // Day + tasks + Celkem

    // Task totals
    final Map<String, int> taskTotals = {};
    for (final t in allTasks) {
      taskTotals[t] = 0;
    }
    int grandTotal = 0;

    // Rows
    final List<List<String>> rows = [];
    for (int day = 1; day <= numDays; day++) {
      final row = <String>['$day.${data.month}.${data.year}'];
      int dayTotal = 0;
      for (final task in allTasks) {
        final minutes = data.dayTaskMinutes[day]?[task] ?? 0;
        taskTotals[task] = taskTotals[task]! + minutes;
        dayTotal += minutes;
        row.add(minutes > 0 ? _minutesToHHMM(minutes) : '');
      }
      grandTotal += dayTotal;
      row.add(dayTotal > 0 ? _minutesToHHMM(dayTotal) : '');
      rows.add(row);
    }

    // Totals row
    final totalsRow = <String>['CELKEM'];
    for (final task in allTasks) {
      totalsRow.add(_minutesToHHMM(taskTotals[task]!));
    }
    totalsRow.add(_minutesToHHMM(grandTotal));

    // Calculate column widths
    final availableWidth = PdfPageFormat.a4.width - 2 * PdfPageFormat.cm;
    final dayColWidth = 55.0;
    final totalColWidth = 45.0;
    final taskColWidth = allTasks.isNotEmpty ? (availableWidth - dayColWidth - totalColWidth) / allTasks.length : availableWidth - dayColWidth - totalColWidth;

    final colWidths = <int, pw.TableColumnWidth>{0: pw.FixedColumnWidth(dayColWidth), numCols - 1: pw.FixedColumnWidth(totalColWidth)};
    for (int i = 1; i <= allTasks.length; i++) {
      colWidths[i] = pw.FixedColumnWidth(taskColWidth.clamp(30, 200));
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: PdfPageFormat.cm, vertical: 1.5 * PdfPageFormat.cm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Title
              pw.Center(
                child: pw.Text(
                  '$monthName ${data.year}',
                  style: pw.TextStyle(font: fonts.bold, fontSize: 16, color: const PdfColor.fromInt(0xFF333333)),
                ),
              ),
              pw.SizedBox(height: 0.3 * PdfPageFormat.cm),

              // Main table
              pw.Table(
                columnWidths: colWidths,
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                children: [
                  // Header row
                  pw.TableRow(
                    children: [
                      _cell('Den', fonts.bold, 7, align: pw.TextAlign.center, bg: headerBg, textColor: PdfColors.white),
                      ...allTasks.map((t) => _cell(t, fonts.bold, 7, align: pw.TextAlign.center, bg: headerBg, textColor: PdfColors.white)),
                      _cell('Celkem', fonts.bold, 7, align: pw.TextAlign.center, bg: headerBg, textColor: PdfColors.white),
                    ],
                  ),
                  // Data rows
                  for (int i = 0; i < rows.length; i++)
                    pw.TableRow(
                      children: [
                        _cell(rows[i][0], fonts.bold, 6, align: pw.TextAlign.center, bg: dayColBg),
                        for (int j = 1; j < rows[i].length - 1; j++) _cell(rows[i][j], fonts.regular, 6, align: pw.TextAlign.right, bg: i.isEven ? PdfColors.white : altRowBg),
                        _cell(rows[i].last, fonts.bold, 6, align: pw.TextAlign.right, bg: totalColBg),
                      ],
                    ),
                  // Totals row
                  pw.TableRow(
                    children: [
                      _cell(totalsRow[0], fonts.bold, 6, align: pw.TextAlign.center, bg: totalRowBg, textColor: PdfColors.white),
                      for (int j = 1; j < totalsRow.length - 1; j++) _cell(totalsRow[j], fonts.bold, 6, align: pw.TextAlign.right, bg: totalRowBg, textColor: PdfColors.white),
                      _cell(totalsRow.last, fonts.bold, 6, align: pw.TextAlign.right, bg: totalRowBg, textColor: PdfColors.white),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 0.5 * PdfPageFormat.cm),

              // Summary table
              _buildSummaryTable(grandTotal, data.hourlyRate, fonts),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _cell(String text, pw.Font font, double fontSize, {pw.TextAlign align = pw.TextAlign.left, PdfColor? bg, PdfColor textColor = PdfColors.black}) {
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      alignment: align == pw.TextAlign.center
          ? pw.Alignment.center
          : align == pw.TextAlign.right
          ? pw.Alignment.centerRight
          : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: fontSize, color: textColor),
      ),
    );
  }

  pw.Widget _buildSummaryTable(int totalMinutes, double hourlyRate, ({pw.Font regular, pw.Font bold}) fonts) {
    final totalHours = totalMinutes / 60;
    final totalAmount = totalHours * hourlyRate;
    final amountFormatted = '${NumberFormat('#,##0.00', 'cs').format(totalAmount)} Kč';

    return pw.Table(
      columnWidths: {0: const pw.FixedColumnWidth(4 * PdfPageFormat.cm), 1: const pw.FixedColumnWidth(4 * PdfPageFormat.cm)},
      border: pw.TableBorder.all(color: PdfColors.black, width: 1),
      children: [
        pw.TableRow(
          children: [
            _summaryCell('Celkový čas:', fonts.bold, 10),
            _summaryCell(_minutesToHHMM(totalMinutes), fonts.regular, 10, align: pw.TextAlign.right),
          ],
        ),
        pw.TableRow(
          children: [
            _summaryCell('Cena za hodinu:', fonts.bold, 10),
            _summaryCell('${hourlyRate.toStringAsFixed(0)} Kč', fonts.regular, 10, align: pw.TextAlign.right),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFD966)),
          children: [
            _summaryCell('Celkem Kč:', fonts.bold, 11),
            _summaryCell(amountFormatted, fonts.bold, 11, align: pw.TextAlign.right),
          ],
        ),
      ],
    );
  }

  pw.Widget _summaryCell(String text, pw.Font font, double fontSize, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      alignment: align == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: fontSize),
      ),
    );
  }

  /// Calculate invoice totals (total hours and hourly rate) for a given month.
  /// Uses the same minute-based calculation as the PDF report to ensure consistency.
  /// Each time entry's seconds are truncated to minutes first, then summed,
  /// then divided by 60 to get hours — this matches the issued PDF exactly.
  ({double totalHours, double hourlyRate}) getInvoiceTotals(DateTime monthStart, DateTime monthEnd, {List<String>? projectIds}) {
    final data = _processEntries(monthStart, monthEnd, projectIds: projectIds);
    int grandTotalMinutes = 0;
    for (final dayData in data.dayTaskMinutes.values) {
      for (final mins in dayData.values) {
        grandTotalMinutes += mins;
      }
    }
    final totalHours = grandTotalMinutes / 60;
    return (totalHours: totalHours, hourlyRate: data.hourlyRate);
  }

  /// Generate invoice PDF matching the Python script layout.
  Future<Uint8List> generateInvoicePdf(DateTime monthStart, DateTime monthEnd, {InvoiceSettings? invoiceSettings, List<String>? projectIds}) async {
    final settings = invoiceSettings ?? const InvoiceSettings();
    final fonts = await _loadFonts();
    final data = _processEntries(monthStart, monthEnd, projectIds: projectIds);

    // Calculate totals from processed data — round hours to 1 decimal so
    // displayed quantity × displayed rate = displayed total.
    final totals = getInvoiceTotals(monthStart, monthEnd, projectIds: projectIds);
    final totalHours = totals.totalHours;
    final hourlyRate = totals.hourlyRate;
    final totalAmount = totalHours * hourlyRate;

    // Invoice details
    final issueDate = DateTime.now();
    final dueDate = issueDate.add(const Duration(days: 14));
    final invoiceNumber = '${issueDate.year}-${data.month.toString().padLeft(5, '0')}';
    final vs = '${issueDate.year}${data.month.toString().padLeft(5, '0')}';

    // Format numbers
    final totalHoursFmt = totalHours.toStringAsFixed(1).replaceAll('.', ',');
    final hourlyRateFmt = hourlyRate.toStringAsFixed(2).replaceAll('.', ',');
    final totalAmountInt = totalAmount.truncate();
    final totalAmountDec = ((totalAmount - totalAmountInt) * 100).round();
    final totalAmountFmt = '${NumberFormat('#,###', 'cs').format(totalAmountInt).replaceAll(',', '.')},${totalAmountDec.toString().padLeft(2, '0')}';

    final pdf = pw.Document();

    final pageWidth = PdfPageFormat.a4.width - 30 * PdfPageFormat.mm;
    final halfWidth = pageWidth / 2;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // === Header: name + invoice number ===
              pw.Table(
                columnWidths: {0: pw.FixedColumnWidth(halfWidth), 1: pw.FixedColumnWidth(halfWidth)},
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 8),
                        child: pw.Text(settings.supplier.name, style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                      ),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'FAKTURA - DOKLAD',
                                style: pw.TextStyle(font: fonts.bold, fontSize: 9),
                              ),
                              pw.TextSpan(
                                text: ' č. ',
                                style: pw.TextStyle(font: fonts.regular, fontSize: 9),
                              ),
                              pw.TextSpan(
                                text: invoiceNumber,
                                style: pw.TextStyle(font: fonts.bold, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 1 * PdfPageFormat.mm),

              // === Supplier (left) | VS + Buyer (right) — independent heights ===
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left column: Supplier — auto height, no bottom border (continues until bank section)
                  pw.SizedBox(
                    width: halfWidth,
                    child: pw.Container(
                      height: 4.35 * PdfPageFormat.cm,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(width: 0.5), left: pw.BorderSide(width: 0.5)),
                      ),
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text('Dodavatel:', style: pw.TextStyle(font: fonts.regular, fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text(settings.supplier.name, style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text(settings.supplier.addressLine1, style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text(settings.supplier.addressLine2, style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text('IČO: ${settings.supplier.ico}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                          ),
                          if (settings.supplier.phone.isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 8),
                              child: pw.Text('Mobil: ${settings.supplier.phone}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                            ),
                          if (settings.supplier.email.isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 8),
                              child: pw.Text('E-mail: ${settings.supplier.email}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Right column: VS (small) + Buyer below
                  pw.SizedBox(
                    width: halfWidth,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // VS box — small
                        pw.Container(
                          width: halfWidth,
                          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text('Variabilní symbol:            $vs', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                          ),
                        ),
                        // Buyer box
                        pw.Container(
                          height: 3.75 * PdfPageFormat.cm,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(top: pw.BorderSide(width: 1), left: pw.BorderSide(width: 1), right: pw.BorderSide(width: 1)),
                          ),
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(left: 8),
                                      child: pw.Text('Odběratel:', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(left: 8),
                                      child: pw.Text(settings.customer.name, style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(left: 8),
                                      child: pw.Text(settings.customer.addressLine1, style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(left: 8),
                                      child: pw.Text(settings.customer.addressLine2, style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
                                    ),
                                  ],
                                ),
                              ),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.SizedBox(height: 8),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(right: 8),
                                    child: pw.Text('IČO: ${settings.customer.ico}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                                  ),
                                  if (settings.customer.dic.isNotEmpty)
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(right: 8),
                                      child: pw.Text('DIČ: ${settings.customer.dic}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // === Bank info left | empty right ===
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: halfWidth,
                    child: pw.Container(
                      height: 2.2 * PdfPageFormat.cm,
                      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Banka: ${settings.bankName}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                            pw.Text('SWIFT: ${settings.swift}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                            pw.Text('IBAN: ${settings.iban}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                            pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  pw.TextSpan(
                                    text: 'Číslo účtu: ',
                                    style: pw.TextStyle(font: fonts.regular, fontSize: 9),
                                  ),
                                  pw.TextSpan(
                                    text: settings.accountNumber,
                                    style: pw.TextStyle(font: fonts.bold, fontSize: 9),
                                  ),
                                  pw.TextSpan(
                                    text: ' Kód banky: ',
                                    style: pw.TextStyle(font: fonts.regular, fontSize: 9),
                                  ),
                                  pw.TextSpan(
                                    text: settings.bankCode,
                                    style: pw.TextStyle(font: fonts.bold, fontSize: 9),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: halfWidth,
                    child: pw.Container(
                      height: 2.2 * PdfPageFormat.cm,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(right: pw.BorderSide(width: 1), left: pw.BorderSide(width: 1), bottom: pw.BorderSide(width: 1)),
                      ),
                    ),
                  ),
                ],
              ),

              // === Dates ===
              pw.Table(
                columnWidths: {0: pw.FixedColumnWidth(halfWidth), 1: pw.FixedColumnWidth(halfWidth)},
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        height: 2.06 * PdfPageFormat.cm,
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _dateRow('Datum vystavení:', DateFormat('dd.MM.yyyy').format(issueDate), fonts),
                              _dateRow('Datum splatnosti:', DateFormat('dd.MM.yyyy').format(dueDate), fonts),
                              _dateRow('Forma úhrady:', 'bankovní převod', fonts),
                            ],
                          ),
                        ),
                      ),
                      pw.Container(height: 2.06 * PdfPageFormat.cm),
                    ],
                  ),
                ],
              ),

              // === Items table ===
              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(8.5 * PdfPageFormat.cm),
                  1: const pw.FixedColumnWidth(2 * PdfPageFormat.cm),
                  2: const pw.FixedColumnWidth(1.5 * PdfPageFormat.cm),
                  3: const pw.FixedColumnWidth(2 * PdfPageFormat.cm),
                  4: const pw.FixedColumnWidth(1.5 * PdfPageFormat.cm),
                  5: const pw.FixedColumnWidth(2.5 * PdfPageFormat.cm),
                },
                border: const pw.TableBorder(top: pw.BorderSide(width: 0.5), bottom: pw.BorderSide(width: 0.5), left: pw.BorderSide(width: 0.5), right: pw.BorderSide(width: 0.5)),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFD3D3D3)),
                    children: [
                      _invoiceCell('Označení zboží - služby', fonts.bold, 9, left: 8),
                      _invoiceCell('Množ.', fonts.bold, 9, align: pw.TextAlign.right),
                      _invoiceCell('MJ', fonts.bold, 9, align: pw.TextAlign.right),
                      _invoiceCell('Cena', fonts.bold, 9, align: pw.TextAlign.right),
                      _invoiceCell('Sleva', fonts.bold, 9, align: pw.TextAlign.right),
                      _invoiceCell('CZK Celkem', fonts.bold, 9, align: pw.TextAlign.right),
                    ],
                  ),
                  // Item row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                    children: [
                      _invoiceCell(settings.description, fonts.regular, 9, left: 8),
                      _invoiceCell(totalHoursFmt, fonts.regular, 9, align: pw.TextAlign.right),
                      _invoiceCell('hod', fonts.regular, 9, align: pw.TextAlign.right),
                      _invoiceCell(hourlyRateFmt, fonts.regular, 9, align: pw.TextAlign.right),
                      _invoiceCell('0%', fonts.regular, 9, align: pw.TextAlign.right),
                      _invoiceCell(totalAmountFmt, fonts.regular, 9, align: pw.TextAlign.right),
                    ],
                  ),
                  // Sum row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))),
                    children: [
                      _invoiceCell('Součet položek', fonts.bold, 9, left: 8),
                      _invoiceCell(totalHoursFmt, fonts.regular, 9, align: pw.TextAlign.right),
                      _invoiceCell('', fonts.regular, 9),
                      _invoiceCell('', fonts.regular, 9),
                      _invoiceCell('', fonts.regular, 9),
                      _invoiceCell(totalAmountFmt, fonts.regular, 9, align: pw.TextAlign.right),
                    ],
                  ),
                ],
              ),

              // === CELKEM K ÚHRADĚ ===
              pw.Table(
                columnWidths: {0: const pw.FixedColumnWidth(13 * PdfPageFormat.cm), 1: const pw.FixedColumnWidth(5 * PdfPageFormat.cm)},
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: pw.Text('CELKEM K ÚHRADĚ', style: pw.TextStyle(font: fonts.bold, fontSize: 10)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                        alignment: pw.Alignment.centerRight,
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'CZK ',
                                style: pw.TextStyle(font: fonts.bold, fontSize: 10),
                              ),
                              pw.TextSpan(
                                text: totalAmountFmt,
                                style: pw.TextStyle(font: fonts.bold, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // === Signature section ===
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                height: 9.6 * PdfPageFormat.cm,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left: Vystavil + QR
                    pw.SizedBox(
                      width: halfWidth,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 8),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Vystavil:', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                                  pw.Text(settings.issuerName, style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                                  pw.Text(settings.issuerEmail, style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                                ],
                              ),
                            ),
                            pw.SizedBox(height: 12),
                            // QR code
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 8),
                              child: pw.Column(
                                children: [
                                  pw.BarcodeWidget(
                                    barcode: pw.Barcode.qrCode(),
                                    data: 'SPD*1.0*ACC:${settings.iban}*AM:${totalAmount.toStringAsFixed(2)}*CC:CZK*X-VS:$vs*MSG:${settings.description}',
                                    width: 4 * PdfPageFormat.cm,
                                    height: 4 * PdfPageFormat.cm,
                                  ),
                                  pw.SizedBox(height: 1),
                                  pw.Text('QR Platba+F', style: pw.TextStyle(font: fonts.regular, fontSize: 8)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right: Převzal + Razítko
                    pw.SizedBox(
                      width: halfWidth,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 48, top: 3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Převzal:', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                            pw.SizedBox(height: 60),
                            pw.Text('Razítko:', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _dateRow(String label, String value, ({pw.Font regular, pw.Font bold}) fonts) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 5 * PdfPageFormat.cm,
            child: pw.Text(label, style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
          ),
          pw.Text(value, style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _invoiceCell(String text, pw.Font font, double fontSize, {pw.TextAlign align = pw.TextAlign.left, double left = 0}) {
    return pw.Container(
      padding: pw.EdgeInsets.only(left: left, right: 3, top: 4, bottom: 4),
      alignment: align == pw.TextAlign.right
          ? pw.Alignment.centerRight
          : align == pw.TextAlign.center
          ? pw.Alignment.center
          : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: fontSize),
      ),
    );
  }

  /// Generate all 3 PDFs and save them to [outputDir].
  /// Returns the list of generated file paths.
  Future<List<String>> generateAllReports(DateTime monthStart, DateTime monthEnd, String outputDir, {InvoiceSettings? invoiceSettings, List<String>? projectIds}) async {
    final settings = invoiceSettings ?? const InvoiceSettings();
    final month = monthStart.month;
    final year = monthStart.year;
    final monthName = _czechMonthsLower[month] ?? '$month';

    String resolveFilename(String pattern) {
      return pattern.replaceAll('{month}', monthName).replaceAll('{year}', '$year');
    }

    final paths = <String>[];

    // 1. Report (original)
    final reportBytes = await generateReportPdf(monthStart, monthEnd, moveAnglictina: false, projectIds: projectIds);
    final reportPath = '$outputDir/${resolveFilename(settings.reportFilename)}.pdf';
    await File(reportPath).writeAsBytes(reportBytes);
    paths.add(reportPath);

    // 2. Report (režijní variant)
    final rezijniBytes = await generateReportPdf(monthStart, monthEnd, moveAnglictina: true, projectIds: projectIds);
    final rezijniPath = '$outputDir/${resolveFilename(settings.reportRezijniFilename)}.pdf';
    await File(rezijniPath).writeAsBytes(rezijniBytes);
    paths.add(rezijniPath);

    // 3. Invoice
    final invoiceBytes = await generateInvoicePdf(monthStart, monthEnd, invoiceSettings: settings, projectIds: projectIds);
    final invoicePath = '$outputDir/${resolveFilename(settings.invoiceFilename)}.pdf';
    await File(invoicePath).writeAsBytes(invoiceBytes);
    paths.add(invoicePath);

    return paths;
  }

  /// Generate invoice PDF from a standalone invoice model.
  /// Uses the same layout as time-based invoices but with custom line items.
  Future<Uint8List> generateStandaloneInvoicePdf(StandaloneInvoiceModel invoice) async {
    final fonts = await _loadFonts();

    final supplier = InvoiceParty.fromJson(invoice.supplierJson);
    final customer = InvoiceParty.fromJson(invoice.customerJson);

    final invoiceNumber = invoice.invoiceNumberFormatted;
    final vs = invoice.variableSymbol;
    final issueDate = invoice.issueDate;
    final dueDate = invoice.dueDate;
    final totalAmount = invoice.totalAmount;

    // Format total amount
    final totalAmountInt = totalAmount.truncate();
    final totalAmountDec = ((totalAmount - totalAmountInt) * 100).round();
    final totalAmountFmt = '${NumberFormat('#,###', 'cs').format(totalAmountInt).replaceAll(',', '.')},${totalAmountDec.toString().padLeft(2, '0')}';

    final pdf = pw.Document();

    final pageWidth = PdfPageFormat.a4.width - 30 * PdfPageFormat.mm;
    final halfWidth = pageWidth / 2;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // === Header: name + invoice number ===
              pw.Table(
                columnWidths: {0: pw.FixedColumnWidth(halfWidth), 1: pw.FixedColumnWidth(halfWidth)},
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 8),
                        child: pw.Text(supplier.name, style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                      ),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'FAKTURA - DOKLAD',
                                style: pw.TextStyle(font: fonts.bold, fontSize: 9),
                              ),
                              pw.TextSpan(
                                text: ' č. ',
                                style: pw.TextStyle(font: fonts.regular, fontSize: 9),
                              ),
                              pw.TextSpan(
                                text: invoiceNumber,
                                style: pw.TextStyle(font: fonts.bold, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 1 * PdfPageFormat.mm),

              // === Supplier (left) | VS + Buyer (right) ===
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: halfWidth,
                    child: pw.Container(
                      height: 4.35 * PdfPageFormat.cm,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(width: 0.5), left: pw.BorderSide(width: 0.5)),
                      ),
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text('Dodavatel:', style: pw.TextStyle(font: fonts.regular, fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text(supplier.name, style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text(supplier.addressLine1, style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text(supplier.addressLine2, style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text('IČO: ${supplier.ico}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                          ),
                          if (supplier.phone.isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 8),
                              child: pw.Text('Mobil: ${supplier.phone}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                            ),
                          if (supplier.email.isNotEmpty)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 8),
                              child: pw.Text('E-mail: ${supplier.email}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: halfWidth,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: halfWidth,
                          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text('Variabilní symbol:            $vs', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                          ),
                        ),
                        pw.Container(
                          height: 3.75 * PdfPageFormat.cm,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(top: pw.BorderSide(width: 1), left: pw.BorderSide(width: 1), right: pw.BorderSide(width: 1)),
                          ),
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(left: 8),
                                      child: pw.Text('Odběratel:', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(left: 8),
                                      child: pw.Text(customer.name, style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(left: 8),
                                      child: pw.Text(customer.addressLine1, style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(left: 8),
                                      child: pw.Text(customer.addressLine2, style: pw.TextStyle(font: fonts.bold, fontSize: 9)),
                                    ),
                                  ],
                                ),
                              ),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.SizedBox(height: 8),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(right: 8),
                                    child: pw.Text('IČO: ${customer.ico}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                                  ),
                                  if (customer.dic.isNotEmpty)
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(right: 8),
                                      child: pw.Text('DIČ: ${customer.dic}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // === Bank info left | empty right ===
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: halfWidth,
                    child: pw.Container(
                      height: 2.2 * PdfPageFormat.cm,
                      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Banka: ${invoice.bankName}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                            pw.Text('SWIFT: ${invoice.swift}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                            pw.Text('IBAN: ${invoice.iban}', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                            pw.RichText(
                              text: pw.TextSpan(
                                children: [
                                  pw.TextSpan(
                                    text: 'Číslo účtu: ',
                                    style: pw.TextStyle(font: fonts.regular, fontSize: 9),
                                  ),
                                  pw.TextSpan(
                                    text: invoice.accountNumber,
                                    style: pw.TextStyle(font: fonts.bold, fontSize: 9),
                                  ),
                                  pw.TextSpan(
                                    text: ' Kód banky: ',
                                    style: pw.TextStyle(font: fonts.regular, fontSize: 9),
                                  ),
                                  pw.TextSpan(
                                    text: invoice.bankCode,
                                    style: pw.TextStyle(font: fonts.bold, fontSize: 9),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: halfWidth,
                    child: pw.Container(
                      height: 2.2 * PdfPageFormat.cm,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(right: pw.BorderSide(width: 1), left: pw.BorderSide(width: 1), bottom: pw.BorderSide(width: 1)),
                      ),
                    ),
                  ),
                ],
              ),

              // === Dates ===
              pw.Table(
                columnWidths: {0: pw.FixedColumnWidth(halfWidth), 1: pw.FixedColumnWidth(halfWidth)},
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        height: 2.06 * PdfPageFormat.cm,
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _dateRow('Datum vystavění:', DateFormat('dd.MM.yyyy').format(issueDate), fonts),
                              _dateRow('Datum splatnosti:', DateFormat('dd.MM.yyyy').format(dueDate), fonts),
                              _dateRow('Forma úhrady:', 'bankovní převod', fonts),
                            ],
                          ),
                        ),
                      ),
                      pw.Container(height: 2.06 * PdfPageFormat.cm),
                    ],
                  ),
                ],
              ),

              // === Items table ===
              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(8.5 * PdfPageFormat.cm),
                  1: const pw.FixedColumnWidth(2 * PdfPageFormat.cm),
                  2: const pw.FixedColumnWidth(1.5 * PdfPageFormat.cm),
                  3: const pw.FixedColumnWidth(2 * PdfPageFormat.cm),
                  4: const pw.FixedColumnWidth(1.5 * PdfPageFormat.cm),
                  5: const pw.FixedColumnWidth(2.5 * PdfPageFormat.cm),
                },
                border: const pw.TableBorder(top: pw.BorderSide(width: 0.5), bottom: pw.BorderSide(width: 0.5), left: pw.BorderSide(width: 0.5), right: pw.BorderSide(width: 0.5)),
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFD3D3D3)),
                    children: [
                      _invoiceCell('Označení zboží - služby', fonts.bold, 9, left: 8),
                      _invoiceCell('Množ.', fonts.bold, 9, align: pw.TextAlign.right),
                      _invoiceCell('MJ', fonts.bold, 9, align: pw.TextAlign.right),
                      _invoiceCell('Cena', fonts.bold, 9, align: pw.TextAlign.right),
                      _invoiceCell('Sleva', fonts.bold, 9, align: pw.TextAlign.right),
                      _invoiceCell('CZK Celkem', fonts.bold, 9, align: pw.TextAlign.right),
                    ],
                  ),
                  // Line item rows
                  for (final item in invoice.lineItems)
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                      children: [
                        _invoiceCell(item.description, fonts.regular, 9, left: 8),
                        _invoiceCell(item.quantity.toStringAsFixed(1).replaceAll('.', ','), fonts.regular, 9, align: pw.TextAlign.right),
                        _invoiceCell(item.unit, fonts.regular, 9, align: pw.TextAlign.right),
                        _invoiceCell(item.unitPrice.toStringAsFixed(2).replaceAll('.', ','), fonts.regular, 9, align: pw.TextAlign.right),
                        _invoiceCell(item.discountPercent > 0 ? '${item.discountPercent.toStringAsFixed(0)}%' : '0%', fonts.regular, 9, align: pw.TextAlign.right),
                        _invoiceCell(_formatAmount(item.total), fonts.regular, 9, align: pw.TextAlign.right),
                      ],
                    ),
                  // Sum row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))),
                    children: [
                      _invoiceCell('Součet položek', fonts.bold, 9, left: 8),
                      _invoiceCell('', fonts.regular, 9),
                      _invoiceCell('', fonts.regular, 9),
                      _invoiceCell('', fonts.regular, 9),
                      _invoiceCell('', fonts.regular, 9),
                      _invoiceCell(totalAmountFmt, fonts.regular, 9, align: pw.TextAlign.right),
                    ],
                  ),
                ],
              ),

              // === CELKEM K ÚHRADĚ ===
              pw.Table(
                columnWidths: {0: const pw.FixedColumnWidth(13 * PdfPageFormat.cm), 1: const pw.FixedColumnWidth(5 * PdfPageFormat.cm)},
                border: pw.TableBorder.all(width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: pw.Text('CELKEM K ÚHRADĚ', style: pw.TextStyle(font: fonts.bold, fontSize: 10)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                        alignment: pw.Alignment.centerRight,
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: 'CZK ',
                                style: pw.TextStyle(font: fonts.bold, fontSize: 10),
                              ),
                              pw.TextSpan(
                                text: totalAmountFmt,
                                style: pw.TextStyle(font: fonts.bold, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // === Signature section ===
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                height: 9.6 * PdfPageFormat.cm,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: halfWidth,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 8),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Vystavil:', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                                  pw.Text(invoice.issuerName, style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                                  pw.Text(invoice.issuerEmail, style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                                ],
                              ),
                            ),
                            pw.SizedBox(height: 12),
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 8),
                              child: pw.Column(
                                children: [
                                  pw.BarcodeWidget(
                                    barcode: pw.Barcode.qrCode(),
                                    data:
                                        'SPD*1.0*ACC:${invoice.iban}*AM:${totalAmount.toStringAsFixed(2)}*CC:CZK*X-VS:$vs*MSG:${invoice.lineItems.isNotEmpty ? invoice.lineItems.first.description : ''}',
                                    width: 4 * PdfPageFormat.cm,
                                    height: 4 * PdfPageFormat.cm,
                                  ),
                                  pw.SizedBox(height: 1),
                                  pw.Text('QR Platba+F', style: pw.TextStyle(font: fonts.regular, fontSize: 8)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(
                      width: halfWidth,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 48, top: 3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Převzal:', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                            pw.SizedBox(height: 60),
                            pw.Text('Razítko:', style: pw.TextStyle(font: fonts.regular, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Format a monetary amount Czech-style: e.g. 12.345,00
  String _formatAmount(double amount) {
    final amountInt = amount.truncate();
    final amountDec = ((amount - amountInt) * 100).round();
    return '${NumberFormat('#,###', 'cs').format(amountInt).replaceAll(',', '.')},${amountDec.toString().padLeft(2, '0')}';
  }
}

class _ReportData {
  final int year;
  final int month;
  final Map<int, Map<String, int>> dayTaskMinutes;
  final List<String> sortedTasks;
  final double hourlyRate;

  _ReportData({required this.year, required this.month, required this.dayTaskMinutes, required this.sortedTasks, required this.hourlyRate});
}
