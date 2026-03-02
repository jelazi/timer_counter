import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/standalone_invoice_repository.dart';
import 'standalone_invoice_event.dart';
import 'standalone_invoice_state.dart';

class StandaloneInvoiceBloc extends Bloc<StandaloneInvoiceEvent, StandaloneInvoiceState> {
  final StandaloneInvoiceRepository _repository;

  StandaloneInvoiceBloc({required StandaloneInvoiceRepository repository}) : _repository = repository, super(const StandaloneInvoiceInitial()) {
    on<LoadStandaloneInvoices>(_onLoad);
    on<AddStandaloneInvoice>(_onAdd);
    on<UpdateStandaloneInvoice>(_onUpdate);
    on<DeleteStandaloneInvoice>(_onDelete);
  }

  void _onLoad(LoadStandaloneInvoices event, Emitter<StandaloneInvoiceState> emit) {
    try {
      emit(const StandaloneInvoiceLoading());
      final invoices = _repository.getAll();
      final nextNumber = _repository.getNextStandaloneInvoiceNumber();
      emit(StandaloneInvoiceLoaded(invoices, nextInvoiceNumber: nextNumber));
    } catch (e) {
      emit(StandaloneInvoiceError(e.toString()));
    }
  }

  Future<void> _onAdd(AddStandaloneInvoice event, Emitter<StandaloneInvoiceState> emit) async {
    try {
      await _repository.add(event.invoice);
      final invoices = _repository.getAll();
      final nextNumber = _repository.getNextStandaloneInvoiceNumber();
      emit(StandaloneInvoiceLoaded(invoices, nextInvoiceNumber: nextNumber));
    } catch (e) {
      emit(StandaloneInvoiceError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateStandaloneInvoice event, Emitter<StandaloneInvoiceState> emit) async {
    try {
      await _repository.update(event.invoice);
      final invoices = _repository.getAll();
      final nextNumber = _repository.getNextStandaloneInvoiceNumber();
      emit(StandaloneInvoiceLoaded(invoices, nextInvoiceNumber: nextNumber));
    } catch (e) {
      emit(StandaloneInvoiceError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteStandaloneInvoice event, Emitter<StandaloneInvoiceState> emit) async {
    try {
      await _repository.delete(event.invoiceId);
      final invoices = _repository.getAll();
      final nextNumber = _repository.getNextStandaloneInvoiceNumber();
      emit(StandaloneInvoiceLoaded(invoices, nextInvoiceNumber: nextNumber));
    } catch (e) {
      emit(StandaloneInvoiceError(e.toString()));
    }
  }
}
