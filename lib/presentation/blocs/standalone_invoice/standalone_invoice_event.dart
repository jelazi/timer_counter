import 'package:equatable/equatable.dart';

import '../../../data/models/standalone_invoice_model.dart';

abstract class StandaloneInvoiceEvent extends Equatable {
  const StandaloneInvoiceEvent();

  @override
  List<Object?> get props => [];
}

class LoadStandaloneInvoices extends StandaloneInvoiceEvent {
  const LoadStandaloneInvoices();
}

class AddStandaloneInvoice extends StandaloneInvoiceEvent {
  final StandaloneInvoiceModel invoice;
  const AddStandaloneInvoice(this.invoice);

  @override
  List<Object?> get props => [invoice];
}

class UpdateStandaloneInvoice extends StandaloneInvoiceEvent {
  final StandaloneInvoiceModel invoice;
  const UpdateStandaloneInvoice(this.invoice);

  @override
  List<Object?> get props => [invoice];
}

class DeleteStandaloneInvoice extends StandaloneInvoiceEvent {
  final String invoiceId;
  const DeleteStandaloneInvoice(this.invoiceId);

  @override
  List<Object?> get props => [invoiceId];
}
