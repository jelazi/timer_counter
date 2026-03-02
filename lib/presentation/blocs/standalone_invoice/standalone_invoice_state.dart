import 'package:equatable/equatable.dart';

import '../../../data/models/standalone_invoice_model.dart';

abstract class StandaloneInvoiceState extends Equatable {
  const StandaloneInvoiceState();

  @override
  List<Object?> get props => [];
}

class StandaloneInvoiceInitial extends StandaloneInvoiceState {
  const StandaloneInvoiceInitial();
}

class StandaloneInvoiceLoading extends StandaloneInvoiceState {
  const StandaloneInvoiceLoading();
}

class StandaloneInvoiceLoaded extends StandaloneInvoiceState {
  final List<StandaloneInvoiceModel> invoices;
  final int nextInvoiceNumber;

  const StandaloneInvoiceLoaded(this.invoices, {this.nextInvoiceNumber = 0});

  @override
  List<Object?> get props => [invoices, nextInvoiceNumber];
}

class StandaloneInvoiceError extends StandaloneInvoiceState {
  final String message;
  const StandaloneInvoiceError(this.message);

  @override
  List<Object?> get props => [message];
}
