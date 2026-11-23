import 'package:uuid/uuid.dart';

import '../../data/models/client_model.dart';
import '../../data/models/invoice_settings.dart';
import '../../data/models/project_client_model.dart';
import '../../data/models/standalone_invoice_model.dart';
import '../../data/models/supplier_profile.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/project_client_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/standalone_invoice_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import 'pocketbase_sync_service.dart';

/// What [ClientMigrationService.apply] would create or change. Nothing is ever deleted.
class ClientMigrationPlan {
  /// New clients, each with the names of the projects it gets linked to.
  final List<ClientModel> newClients;
  final List<ProjectClientModel> newLinks;

  /// Invoices that get their `clientId` filled in.
  final List<StandaloneInvoiceModel> updatedInvoices;
  final SupplierProfile? newProfile;

  const ClientMigrationPlan({this.newClients = const [], this.newLinks = const [], this.updatedInvoices = const [], this.newProfile});

  bool get isEmpty => newClients.isEmpty && newLinks.isEmpty && updatedInvoices.isEmpty && newProfile == null;
}

/// Builds clients from the customers on existing invoices (and the old saved
/// customer list), links them to the projects they were invoiced for, and
/// records the client on each invoice. Running it again only adds what is missing.
class ClientMigrationService {
  final StandaloneInvoiceRepository _invoiceRepository;
  final ClientRepository _clientRepository;
  final ProjectClientRepository _linkRepository;
  final ProjectRepository _projectRepository;
  final TimeEntryRepository _timeEntryRepository;
  final SettingsRepository _settingsRepository;

  ClientMigrationService({
    required StandaloneInvoiceRepository invoiceRepository,
    required ClientRepository clientRepository,
    required ProjectClientRepository projectClientRepository,
    required ProjectRepository projectRepository,
    required TimeEntryRepository timeEntryRepository,
    required SettingsRepository settingsRepository,
  }) : _invoiceRepository = invoiceRepository,
       _clientRepository = clientRepository,
       _linkRepository = projectClientRepository,
       _projectRepository = projectRepository,
       _timeEntryRepository = timeEntryRepository,
       _settingsRepository = settingsRepository;

  /// Same company: equal IČO, or equal name when either side has no IČO.
  static String _key(InvoiceParty party) {
    final ico = party.ico.replaceAll(RegExp(r'\s'), '');
    return ico.isNotEmpty ? 'ico:$ico' : 'name:${party.name.trim().toLowerCase()}';
  }

  static String _clientKey(ClientModel c) => _key(c.toInvoiceParty());

  ClientMigrationPlan buildPlan() {
    final invoices = _invoiceRepository.getAll()..sort((a, b) => a.taxDate.compareTo(b.taxDate));

    // The newest invoice decides a company's details; the old saved list fills gaps.
    final parties = <String, InvoiceParty>{};
    final firstSeen = <String, DateTime>{};
    for (final party in _settingsRepository.getCustomers()) {
      if (party.name.trim().isEmpty) continue;
      parties.putIfAbsent(_key(party), () => party);
    }
    for (final invoice in invoices) {
      final party = InvoiceParty.fromJson(invoice.customerJson);
      if (party.name.trim().isEmpty) continue;
      parties[_key(party)] = party;
      firstSeen.putIfAbsent(_key(party), () => invoice.taxDate);
    }

    final clientsByKey = {for (final c in _clientRepository.getAll()) _clientKey(c): c};
    final newClients = <ClientModel>[];
    parties.forEach((key, party) {
      if (clientsByKey.containsKey(key)) return;
      final client = ClientModel(
        id: const Uuid().v4(),
        name: party.name.trim(),
        addressLine1: party.addressLine1,
        addressLine2: party.addressLine2,
        ico: party.ico,
        dic: party.dic,
        email: party.email,
        phone: party.phone,
        createdAt: firstSeen[key] ?? DateTime.now(),
      );
      clientsByKey[key] = client;
      newClients.add(client);
    });

    final updatedInvoices = <StandaloneInvoiceModel>[];
    for (final invoice in invoices) {
      if (invoice.clientId != null) continue;
      final client = clientsByKey[_key(InvoiceParty.fromJson(invoice.customerJson))];
      if (client != null) updatedInvoices.add(invoice.copyWith(clientId: client.id));
    }

    // A project is linked to the client it was invoiced to, but only if it had
    // time in an invoiced month — invoices also listed idle projects.
    final links = <String, ProjectClientModel>{};
    final legacyDescription = _settingsRepository.getInvoiceDescription();
    for (final invoice in invoices.where((i) => i.isTimeBased)) {
      final client = clientsByKey[_key(InvoiceParty.fromJson(invoice.customerJson))];
      if (client == null) continue;
      final monthStart = DateTime(invoice.taxDate.year, invoice.taxDate.month);
      final monthEnd = DateTime(invoice.taxDate.year, invoice.taxDate.month + 1, 0, 23, 59, 59);
      final worked = _timeEntryRepository.getByDateRange(monthStart, monthEnd).map((e) => e.projectId).toSet();
      final description = invoice.lineItems.length == 1 ? invoice.lineItems.first.description : legacyDescription;

      for (final projectId in invoice.sourceProjectIds) {
        if (_projectRepository.getById(projectId) == null || !worked.contains(projectId)) continue;
        if (_linkRepository.find(projectId, client.id) != null) continue;
        final key = '$projectId|${client.id}';
        // New links go below the project's existing clients, so its invoice default stays.
        final position = links[key]?.position ?? _linkRepository.getByProject(projectId).length + links.values.where((l) => l.projectId == projectId).length;
        // Invoices are in date order, so the last one wins and dates the link.
        links[key] = ProjectClientModel(
          id: links[key]?.id ?? const Uuid().v4(),
          projectId: projectId,
          clientId: client.id,
          serviceDescription: description,
          createdAt: invoice.taxDate,
          position: position,
        );
      }
    }

    SupplierProfile? newProfile;
    if (_settingsRepository.getSupplierProfile() == null) {
      final effective = _settingsRepository.getEffectiveSupplierProfile();
      if (!effective.isEmpty) newProfile = effective.copyWith(updatedAt: DateTime.now());
    }

    return ClientMigrationPlan(newClients: newClients, newLinks: links.values.toList(), updatedInvoices: updatedInvoices, newProfile: newProfile);
  }

  /// Write the plan locally first, then queue every change for the server.
  Future<void> apply(ClientMigrationPlan plan, {PocketBaseSyncService? syncService}) async {
    for (final client in plan.newClients) {
      await _clientRepository.add(client);
    }
    for (final link in plan.newLinks) {
      await _linkRepository.add(link);
    }
    for (final invoice in plan.updatedInvoices) {
      await _invoiceRepository.update(invoice);
    }
    final profile = plan.newProfile;
    if (profile != null) await _settingsRepository.setSupplierProfile(profile);

    if (syncService == null) return;
    for (final client in plan.newClients) {
      await syncService.pushClient(client);
    }
    for (final link in plan.newLinks) {
      await syncService.pushProjectClient(link);
    }
    for (final invoice in plan.updatedInvoices) {
      await syncService.pushInvoice(invoice);
    }
    if (profile != null) await syncService.pushSupplierProfile();
  }
}
