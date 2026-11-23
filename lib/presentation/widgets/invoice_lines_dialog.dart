import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/desktop_theme.dart';
import '../../data/models/standalone_invoice_model.dart';

/// Review and edit the proposed invoice lines before the invoice is issued.
/// Returns the final lines, or null when cancelled.
class InvoiceLinesDialog extends StatefulWidget {
  final String clientName;
  final List<InvoiceLineItem> lines;

  const InvoiceLinesDialog({super.key, required this.clientName, required this.lines});

  static Future<List<InvoiceLineItem>?> show(BuildContext context, {required String clientName, required List<InvoiceLineItem> lines}) => showDialog<List<InvoiceLineItem>>(
    context: context,
    builder: (_) => InvoiceLinesDialog(clientName: clientName, lines: lines),
  );

  @override
  State<InvoiceLinesDialog> createState() => _InvoiceLinesDialogState();
}

class _LineControllers {
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController unitPrice;

  _LineControllers(InvoiceLineItem item)
    : description = TextEditingController(text: item.description),
      quantity = TextEditingController(text: _number(item.quantity)),
      unit = TextEditingController(text: item.unit),
      unitPrice = TextEditingController(text: _number(item.unitPrice));

  static String _number(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');

  static double _parse(String text) => double.tryParse(text.trim().replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

  InvoiceLineItem toItem() => InvoiceLineItem(description: description.text.trim(), quantity: _parse(quantity.text), unit: unit.text.trim(), unitPrice: _parse(unitPrice.text));

  void dispose() {
    description.dispose();
    quantity.dispose();
    unit.dispose();
    unitPrice.dispose();
  }
}

class _InvoiceLinesDialogState extends State<InvoiceLinesDialog> {
  late final List<_LineControllers> _rows = widget.lines.map(_LineControllers.new).toList();

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  double get _total => _rows.fold<double>(0, (sum, r) => sum + r.toItem().total);

  void _addRow() => setState(() => _rows.add(_LineControllers(const InvoiceLineItem(unit: 'hod'))));

  void _removeRow(int index) => setState(() => _rows.removeAt(index).dispose());

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mac = MacColors.of(context);
    final total = NumberFormat.currency(locale: 'cs', symbol: 'Kč', decimalDigits: 2).format(_total);

    Widget header(String key, {int flex = 1, TextAlign align = TextAlign.left}) => Expanded(
      flex: flex,
      child: Text(tr(key), textAlign: align, style: textTheme.labelSmall),
    );

    return AlertDialog(
      title: Text(tr('invoice_lines.title')),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('invoice_lines.subtitle', namedArgs: {'client': widget.clientName}), style: textTheme.bodySmall),
            const SizedBox(height: 14),
            Row(
              children: [
                header('invoice_lines.description', flex: 6),
                const SizedBox(width: 8),
                header('invoice_lines.quantity', flex: 2, align: TextAlign.right),
                const SizedBox(width: 8),
                header('invoice_lines.unit', flex: 1),
                const SizedBox(width: 8),
                header('invoice_lines.unit_price', flex: 2, align: TextAlign.right),
                const SizedBox(width: 36),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < _rows.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: TextField(controller: _rows[i].description, onChanged: (_) => setState(() {})),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(controller: _rows[i].quantity, textAlign: TextAlign.right, onChanged: (_) => setState(() {})),
                            ),
                            const SizedBox(width: 8),
                            Expanded(flex: 1, child: TextField(controller: _rows[i].unit)),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(controller: _rows[i].unitPrice, textAlign: TextAlign.right, onChanged: (_) => setState(() {})),
                            ),
                            IconButton(icon: const Icon(Icons.remove_circle_outline), tooltip: tr('common.delete'), onPressed: () => _removeRow(i)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                TextButton.icon(onPressed: _addRow, icon: const Icon(Icons.add), label: Text(tr('invoice_lines.add'))),
                const Spacer(),
                Text('${tr('invoice_lines.total')}: ', style: textTheme.bodyMedium?.copyWith(color: mac.secondaryLabel)),
                Text(
                  total,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
        FilledButton(
          onPressed: _rows.isEmpty ? null : () => Navigator.pop(context, _rows.map((r) => r.toItem()).where((i) => i.description.isNotEmpty || i.total != 0).toList()),
          child: Text(tr('invoice_lines.issue')),
        ),
      ],
    );
  }
}
