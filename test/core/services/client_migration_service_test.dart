import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:timer_counter/core/services/client_migration_service.dart';
import 'package:timer_counter/data/models/client_model.dart';
import 'package:timer_counter/data/models/invoice_settings.dart';
import 'package:timer_counter/data/models/project_client_model.dart';
import 'package:timer_counter/data/models/project_model.dart';
import 'package:timer_counter/data/models/standalone_invoice_model.dart';
import 'package:timer_counter/data/models/time_entry_model.dart';
import 'package:timer_counter/data/repositories/client_repository.dart';
import 'package:timer_counter/data/repositories/project_client_repository.dart';
import 'package:timer_counter/data/repositories/project_repository.dart';
import 'package:timer_counter/data/repositories/settings_repository.dart';
import 'package:timer_counter/data/repositories/standalone_invoice_repository.dart';
import 'package:timer_counter/data/repositories/time_entry_repository.dart';

void main() {
  late Directory tempDir;
  late StandaloneInvoiceRepository invoices;
  late ClientRepository clients;
  late ProjectClientRepository links;
  late ProjectRepository projects;
  late TimeEntryRepository entries;
  late SettingsRepository settings;
  late ClientMigrationService service;

  const medutech = InvoiceParty(name: 'Medutech s.r.o.', addressLine1: 'Beranových 130', addressLine2: '19900 PRAHA 18', ico: '08975922', dic: 'CZ08975922');
  const skolka = InvoiceParty(name: 'Mateřská škola', addressLine1: 'Hřbitovní 8', addressLine2: '690 03 Břeclav', ico: '49137182');

  setUpAll(() {
    Hive.registerAdapter(ProjectModelAdapter());
    Hive.registerAdapter(TimeEntryModelAdapter());
    Hive.registerAdapter(InvoiceLineItemAdapter());
    Hive.registerAdapter(StandaloneInvoiceModelAdapter());
    Hive.registerAdapter(ClientModelAdapter());
    Hive.registerAdapter(ProjectClientModelAdapter());
  });

  StandaloneInvoiceModel invoice(int number, InvoiceParty customer, {required int month, List<String> projectIds = const [], String type = 'time_based'}) {
    final taxDate = DateTime(2026, month + 1, 0);
    return StandaloneInvoiceModel(
      id: 'inv$number',
      invoiceNumber: number,
      issueDate: taxDate,
      dueDate: taxDate.add(const Duration(days: 14)),
      taxDate: taxDate,
      customerJson: customer.toJson(),
      lineItems: const [InvoiceLineItem(description: 'Vývoj aplikace Artemis', quantity: 50, unit: 'hod', unitPrice: 550)],
      createdAt: taxDate,
      updatedAt: taxDate,
      invoiceType: type,
      sourceProjectIds: projectIds,
    );
  }

  Future<void> worked(String projectId, int month) => entries.add(
    TimeEntryModel(
      id: '$projectId-$month',
      projectId: projectId,
      taskId: 't',
      startTime: DateTime(2026, month, 10, 9),
      endTime: DateTime(2026, month, 10, 12),
      createdAt: DateTime(2026, month, 10),
    ),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('client_migration_test');
    Hive.init(tempDir.path);
    invoices = StandaloneInvoiceRepository();
    clients = ClientRepository();
    links = ProjectClientRepository();
    projects = ProjectRepository();
    entries = TimeEntryRepository();
    settings = SettingsRepository();
    for (final init in [invoices.init, clients.init, links.init, projects.init, entries.init, settings.init]) {
      await init();
    }
    service = ClientMigrationService(
      invoiceRepository: invoices,
      clientRepository: clients,
      projectClientRepository: links,
      projectRepository: projects,
      timeEntryRepository: entries,
      settingsRepository: settings,
    );

    for (final (id, name) in [('ostatni', '1. Ostatní'), ('artemis', '2. Artemis'), ('test', 'testovací projekt')]) {
      await projects.add(ProjectModel(id: id, name: name, colorValue: 0xFF000000, createdAt: DateTime(2026, 1, 1)));
    }
    await worked('ostatni', 9);
    await worked('artemis', 9);
    await worked('artemis', 10);
    await invoices.add(invoice(3, skolka, month: 3, type: 'standalone'));
    await invoices.add(invoice(9, medutech, month: 9, projectIds: ['ostatni', 'artemis', 'test']));
    await invoices.add(invoice(10, medutech, month: 10, projectIds: ['ostatni', 'artemis', 'test']));
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('one client per company on the invoices, matched by IČO', () async {
    await service.apply(service.buildPlan());

    expect(clients.getAll().map((c) => (c.name, c.ico, c.dic)), [('Mateřská škola', '49137182', ''), ('Medutech s.r.o.', '08975922', 'CZ08975922')]);
  });

  test('every invoice gets the client of its customer', () async {
    await service.apply(service.buildPlan());

    final byName = {for (final c in clients.getAll()) c.name: c.id};
    expect(invoices.getById('inv3')?.clientId, byName['Mateřská škola']);
    expect(invoices.getById('inv9')?.clientId, byName['Medutech s.r.o.']);
    expect(invoices.getById('inv10')?.clientId, byName['Medutech s.r.o.']);
  });

  test('projects are linked only if they had time in an invoiced month, with the invoice text', () async {
    await service.apply(service.buildPlan());

    final medutechId = clients.getAll().firstWhere((c) => c.ico == '08975922').id;
    final linked = links.getByClient(medutechId);
    expect(linked.map((l) => l.projectId).toSet(), {'ostatni', 'artemis'});
    expect(linked.every((l) => l.serviceDescription == 'Vývoj aplikace Artemis'), isTrue);
    expect(links.getByProject('test'), isEmpty);
    expect(links.find('artemis', medutechId)?.createdAt, DateTime(2026, 10, 31));
  });

  test('running it again changes nothing', () async {
    await service.apply(service.buildPlan());

    expect(service.buildPlan().isEmpty, isTrue);
    expect(clients.getAll(), hasLength(2));
  });

  test('a client created by hand with the same IČO is reused, not duplicated', () async {
    await clients.add(ClientModel(id: 'mine', name: 'Medutech', ico: '08975922', createdAt: DateTime(2026, 11, 1)));

    final plan = service.buildPlan();
    await service.apply(plan);

    expect(plan.newClients.map((c) => c.name), ['Mateřská škola']);
    expect(invoices.getById('inv10')?.clientId, 'mine');
    expect(clients.getById('mine')?.name, 'Medutech');
  });

  test('nothing is deleted and the invoices keep everything else', () async {
    final before = invoices.getById('inv9')!;

    await service.apply(service.buildPlan());

    expect(invoices.getAll(), hasLength(3));
    expect(projects.getAll(), hasLength(3));
    expect(invoices.getById('inv9')!.toJson()..remove('clientId'), before.toJson()..remove('clientId'));
  });

  test('the supplier profile is created once from the old invoice settings', () async {
    await settings.setSuppliers([const InvoiceParty(name: 'Lubomír Žižka', ico: '19164165')]);
    await settings.setSelectedSupplierIndex(0);
    await settings.setInvoiceIban('CZ28');

    await service.apply(service.buildPlan());

    expect(settings.getSupplierProfile()?.party.name, 'Lubomír Žižka');
    expect(settings.getSupplierProfile()?.iban, 'CZ28');
    expect(service.buildPlan().newProfile, isNull);
  });
}
