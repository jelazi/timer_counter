import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../models/standalone_invoice_model.dart';

class StandaloneInvoiceRepository {
  late Box<StandaloneInvoiceModel> _box;
  late Box<dynamic> _settingsBox;

  Future<void> init() async {
    _box = await Hive.openBox<StandaloneInvoiceModel>(AppConstants.standaloneInvoicesBox);
    _settingsBox = await Hive.openBox(AppConstants.settingsBox);
  }

  /// Get all invoices (both standalone and time-based), sorted by invoice number descending.
  List<StandaloneInvoiceModel> getAll() {
    return _box.values.toList()..sort((a, b) => b.invoiceNumber.compareTo(a.invoiceNumber));
  }

  /// Get only standalone invoices.
  List<StandaloneInvoiceModel> getStandaloneOnly() {
    return _box.values.where((e) => e.invoiceType == 'standalone').toList()..sort((a, b) => b.invoiceNumber.compareTo(a.invoiceNumber));
  }

  /// Get only time-based invoices.
  List<StandaloneInvoiceModel> getTimeBasedOnly() {
    return _box.values.where((e) => e.invoiceType == 'time_based').toList()..sort((a, b) => b.invoiceNumber.compareTo(a.invoiceNumber));
  }

  StandaloneInvoiceModel? getById(String id) {
    try {
      return _box.values.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(StandaloneInvoiceModel invoice) async {
    await _box.put(invoice.id, invoice);
  }

  Future<void> update(StandaloneInvoiceModel invoice) async {
    await _box.put(invoice.id, invoice);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// Get all invoice numbers currently in use.
  Set<int> getUsedInvoiceNumbers() {
    return _box.values.map((e) => e.invoiceNumber).toSet();
  }

  /// Next number for a time-based invoice for a given month.
  /// Starts at the month number, then increments until a free number is found.
  int getNextTimeBasedInvoiceNumber(int month) {
    final used = getUsedInvoiceNumbers();
    int candidate = month;
    while (used.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

  /// Next number for a standalone invoice.
  /// Finds the first free number starting from 1.
  int getNextStandaloneInvoiceNumber() {
    final used = getUsedInvoiceNumbers();
    int candidate = 1;
    while (used.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

  /// Get the next available invoice number (legacy — shared counter).
  int getNextInvoiceNumber() {
    final current = _settingsBox.get(AppConstants.invoiceNumberCounter, defaultValue: 0) as int;
    return current + 1;
  }

  /// Consume the next invoice number (increment the counter).
  Future<int> consumeNextInvoiceNumber() async {
    final next = getNextInvoiceNumber();
    await _settingsBox.put(AppConstants.invoiceNumberCounter, next);
    return next;
  }

  /// Get the current invoice number counter value.
  int getCurrentInvoiceNumber() {
    return _settingsBox.get(AppConstants.invoiceNumberCounter, defaultValue: 0) as int;
  }

  /// Set the invoice number counter to a specific value (for manual adjustment).
  Future<void> setInvoiceNumberCounter(int value) async {
    await _settingsBox.put(AppConstants.invoiceNumberCounter, value);
  }

  /// Get the highest invoice number used across all invoices.
  int getHighestInvoiceNumber() {
    if (_box.isEmpty) return 0;
    return _box.values.map((e) => e.invoiceNumber).reduce((a, b) => a > b ? a : b);
  }

  /// Find an existing time-based invoice for a given month and year.
  /// Used for dedup — if we regenerate a time-based invoice for the same month, we overwrite.
  StandaloneInvoiceModel? findTimeBasedInvoice({required int month, required int year}) {
    try {
      return _box.values.firstWhere((inv) {
        if (inv.invoiceType != 'time_based') return false;
        // Match by the month the invoice is FOR (issueDate)
        if (inv.issueDate.month != month || inv.issueDate.year != year) return false;
        return true;
      });
    } catch (_) {
      return null;
    }
  }
}
