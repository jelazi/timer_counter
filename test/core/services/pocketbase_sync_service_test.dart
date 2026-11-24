import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timer_counter/core/services/pocketbase_sync_service.dart';
import 'package:timer_counter/core/services/pomodoro_engine.dart';
import 'package:timer_counter/core/services/sync_ledger.dart';
import 'package:timer_counter/data/models/category_model.dart';
import 'package:timer_counter/data/models/client_model.dart';
import 'package:timer_counter/data/models/invoice_settings.dart';
import 'package:timer_counter/data/models/monthly_hours_target_model.dart';
import 'package:timer_counter/data/models/pomodoro_session.dart';
import 'package:timer_counter/data/models/pomodoro_settings.dart';
import 'package:timer_counter/data/models/project_client_model.dart';
import 'package:timer_counter/data/models/project_model.dart';
import 'package:timer_counter/data/models/running_timer_model.dart';
import 'package:timer_counter/data/models/standalone_invoice_model.dart';
import 'package:timer_counter/data/models/supplier_profile.dart';
import 'package:timer_counter/data/models/task_model.dart';
import 'package:timer_counter/data/models/time_entry_model.dart';
import 'package:timer_counter/data/repositories/category_repository.dart';
import 'package:timer_counter/data/repositories/client_repository.dart';
import 'package:timer_counter/data/repositories/monthly_hours_target_repository.dart';
import 'package:timer_counter/data/repositories/pomodoro_repository.dart';
import 'package:timer_counter/data/repositories/project_client_repository.dart';
import 'package:timer_counter/data/repositories/project_repository.dart';
import 'package:timer_counter/data/repositories/running_timer_repository.dart';
import 'package:timer_counter/data/repositories/settings_repository.dart';
import 'package:timer_counter/data/repositories/standalone_invoice_repository.dart';
import 'package:timer_counter/data/repositories/task_repository.dart';
import 'package:timer_counter/data/repositories/time_entry_repository.dart';

const _userId = 'user1';
const _entries = 'time_entries';

class FakePocketBase {
  final Map<String, Map<String, Map<String, dynamic>>> _collections = {};
  int _nextId = 0;

  bool rejectWrites = false;

  /// Collections this server does not have, as on a server whose schema predates them.
  final Set<String> missingCollections = {};

  void seed(String collection, Map<String, dynamic> fields) {
    final id = 'pb${_nextId++}';
    (_collections[collection] ??= {})[id] = {'id': id, 'collectionName': collection, 'user': _userId, ...fields};
  }

  void remove(String collection, String itemId) => _collections[collection]?.removeWhere((_, r) => r['item_id'] == itemId);

  List<Map<String, dynamic>> records(String collection) => _collections[collection]?.values.toList() ?? const [];

  Map<String, dynamic>? record(String collection, String itemId) {
    for (final r in records(collection)) {
      if (r['item_id'] == itemId) return r;
    }
    return null;
  }

  http.Client client() => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    final segments = request.url.pathSegments;
    if (segments.length < 4 || segments[0] != 'api' || segments[1] != 'collections' || segments[3] != 'records') {
      return _json(404, {'message': 'Not found'});
    }
    final collection = segments[2];
    if (missingCollections.contains(collection)) return _json(404, {'message': 'Missing collection context.'});
    final records = _collections[collection] ??= {};
    final recordId = segments.length > 4 ? segments[4] : null;

    if (request.method != 'GET' && rejectWrites) return _json(500, {'message': 'Something went wrong'});

    switch (request.method) {
      case 'GET':
        final query = request.url.queryParameters;
        final itemId = RegExp(r'item_id = "([^"]*)"').firstMatch(query['filter'] ?? '')?.group(1);
        final matches = records.values.where((r) => itemId == null || r['item_id'] == itemId).toList();
        final page = int.parse(query['page'] ?? '1');
        final perPage = int.parse(query['perPage'] ?? '30');
        return _json(200, {
          'page': page,
          'perPage': perPage,
          'totalItems': matches.length,
          'totalPages': (matches.length / perPage).ceil(),
          'items': matches.skip((page - 1) * perPage).take(perPage).toList(),
        });
      case 'POST':
        final id = 'pb${_nextId++}';
        records[id] = {'id': id, 'collectionName': collection, ...jsonDecode(request.body) as Map<String, dynamic>};
        return _json(200, records[id]!);
      case 'PATCH':
        final existing = records[recordId];
        if (existing == null) return _json(404, {'message': 'Not found'});
        existing.addAll(jsonDecode(request.body) as Map<String, dynamic>);
        return _json(200, existing);
      case 'DELETE':
        records.remove(recordId);
        return http.Response('', 204);
    }
    return _json(405, {'message': 'Method not allowed'});
  }

  static http.Response _json(int status, Map<String, dynamic> body) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
}

String _authToken() {
  String part(Map<String, dynamic> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'id': _userId, 'type': 'auth', 'exp': 4102444800})}.signature';
}

void main() {
  late Directory tempDir;
  late FakePocketBase server;
  late SettingsRepository settings;
  late TimeEntryRepository timeEntries;
  late CategoryRepository categories;
  late ProjectRepository projects;
  late TaskRepository tasks;
  late RunningTimerRepository runningTimers;
  late MonthlyHoursTargetRepository monthlyTargets;
  late ClientRepository clients;
  late ProjectClientRepository projectClients;
  late StandaloneInvoiceRepository invoices;
  late PomodoroRepository pomodoro;

  setUpAll(() {
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(ProjectModelAdapter());
    Hive.registerAdapter(TaskModelAdapter());
    Hive.registerAdapter(TimeEntryModelAdapter());
    Hive.registerAdapter(RunningTimerModelAdapter());
    Hive.registerAdapter(MonthlyHoursTargetModelAdapter());
    Hive.registerAdapter(InvoiceLineItemAdapter());
    Hive.registerAdapter(StandaloneInvoiceModelAdapter());
    Hive.registerAdapter(ClientModelAdapter());
    Hive.registerAdapter(ProjectClientModelAdapter());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('timer_counter_pocketbase_sync_test');
    Hive.init(tempDir.path);
    server = FakePocketBase();
    settings = SettingsRepository();
    timeEntries = TimeEntryRepository();
    categories = CategoryRepository();
    projects = ProjectRepository();
    tasks = TaskRepository();
    runningTimers = RunningTimerRepository();
    monthlyTargets = MonthlyHoursTargetRepository();
    clients = ClientRepository();
    projectClients = ProjectClientRepository();
    invoices = StandaloneInvoiceRepository();
    pomodoro = PomodoroRepository();
    for (final init in [
      settings.init,
      timeEntries.init,
      categories.init,
      projects.init,
      tasks.init,
      runningTimers.init,
      monthlyTargets.init,
      clients.init,
      projectClients.init,
      invoices.init,
      pomodoro.init,
    ]) {
      await init();
    }
    await settings.setPocketBaseAuthToken(_authToken());
    await settings.setPocketBaseAuthModel(jsonEncode({'id': _userId, 'collectionId': '_pb_users_auth_', 'collectionName': 'users', 'email': 'user@example.com'}));
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  PocketBaseSyncService createService() => PocketBaseSyncService(
    serverUrl: 'http://pocketbase.test',
    categoryRepo: categories,
    projectRepo: projects,
    taskRepo: tasks,
    timeEntryRepo: timeEntries,
    runningTimerRepo: runningTimers,
    monthlyTargetRepo: monthlyTargets,
    settingsRepo: settings,
    clientRepo: clients,
    projectClientRepo: projectClients,
    invoiceRepo: invoices,
    pomodoroRepo: pomodoro,
    httpClientFactory: server.client,
  );

  TimeEntryModel entry(String id, {String notes = ''}) =>
      TimeEntryModel(id: id, projectId: 'p1', taskId: 't1', startTime: DateTime(2026, 10, 1, 8), endTime: DateTime(2026, 10, 1, 9), notes: notes, createdAt: DateTime(2026, 10, 1));

  Map<String, dynamic> remoteEntry(String id, {String notes = ''}) => {
    'item_id': id,
    'project_id': 'p1',
    'task_id': 't1',
    'start_time': DateTime(2026, 10, 1, 8).toIso8601String(),
    'end_time': DateTime(2026, 10, 1, 9).toIso8601String(),
    'duration_seconds': 0,
    'notes': notes,
    'created_at': DateTime(2026, 10, 1).toIso8601String(),
    'is_billable': true,
  };

  SyncLedger savedLedger() => SyncLedger.decode(settings.getPocketBaseSyncLedger());

  group('downloadAll reconciliation', () {
    Future<void> seedLocalStateAndLedger() async {
      await timeEntries.add(entry('deleted-remotely', notes: 'confirmed earlier'));
      await timeEntries.add(entry('never-uploaded', notes: 'created offline'));
      await timeEntries.add(entry('edited-locally', notes: 'local edit'));
      final ledger = SyncLedger()..setConfirmed(_entries, {'deleted-remotely', 'edited-locally'});
      ledger.markPending(_entries, 'edited-locally', PendingOp.upsert);
      await settings.setPocketBaseSyncLedger(ledger.encode());
      server.seed(_entries, remoteEntry('edited-locally', notes: 'server version'));
    }

    Future<void> downloadWhileServerRejectsWrites() async {
      await seedLocalStateAndLedger();
      server.rejectWrites = true;
      final result = await createService().downloadAll();
      expect(result.error, isNull);
    }

    test('deletes a record the server is known to have had and no longer has', () async {
      await downloadWhileServerRejectsWrites();

      expect(timeEntries.getById('deleted-remotely'), isNull);
    });

    test('keeps a local record the server never had and queues it for upload', () async {
      await downloadWhileServerRejectsWrites();

      expect(timeEntries.getById('never-uploaded')?.notes, 'created offline');
      expect(savedLedger().pendingOp(_entries, 'never-uploaded'), PendingOp.upsert);
    });

    test('does not overwrite a record whose local change has not been sent yet', () async {
      await downloadWhileServerRejectsWrites();

      expect(timeEntries.getById('edited-locally')?.notes, 'local edit');
      expect(savedLedger().pendingOp(_entries, 'edited-locally'), PendingOp.upsert);
    });

    test('uploads the never-uploaded record and the unsent edit once the server accepts writes', () async {
      await seedLocalStateAndLedger();

      final result = await createService().downloadAll();

      expect(result.error, isNull);
      expect(server.record(_entries, 'never-uploaded')?['notes'], 'created offline');
      expect(server.record(_entries, 'edited-locally')?['notes'], 'local edit');
      expect(timeEntries.getById('edited-locally')?.notes, 'local edit');
      expect(savedLedger().pendingCount, 0);
    });
  });

  group('offline queue', () {
    test('a push the server rejects stays queued in the persisted ledger', () async {
      final service = createService();
      server.rejectWrites = true;
      await timeEntries.add(entry('e1', notes: 'v1'));

      await service.pushTimeEntry(timeEntries.getById('e1')!);

      expect(server.record(_entries, 'e1'), isNull);
      expect(savedLedger().pendingOp(_entries, 'e1'), PendingOp.upsert);
    });

    test('the next downloadAll sends a queued record once, in its latest local state', () async {
      final service = createService();
      server.rejectWrites = true;
      await timeEntries.add(entry('e1', notes: 'v1'));
      await service.pushTimeEntry(timeEntries.getById('e1')!);
      await timeEntries.update(entry('e1', notes: 'v2'));
      await service.pushTimeEntry(timeEntries.getById('e1')!);

      server.rejectWrites = false;
      final result = await service.downloadAll();

      expect(result.error, isNull);
      expect(server.records(_entries).map((r) => r['notes']), ['v2']);
      expect(timeEntries.getById('e1')?.notes, 'v2');
      expect(savedLedger().pendingCount, 0);
    });

    test('a queued upsert for a record deleted locally is dropped instead of sent', () async {
      final service = createService();
      server.rejectWrites = true;
      await timeEntries.add(entry('e1'));
      await service.pushTimeEntry(timeEntries.getById('e1')!);
      await timeEntries.delete('e1');

      server.rejectWrites = false;
      final result = await service.downloadAll();

      expect(result.error, isNull);
      expect(server.records(_entries), isEmpty);
      expect(savedLedger().pendingCount, 0);
    });
  });

  group('clients, links, invoices and the supplier profile', () {
    const newCollections = ['clients', 'project_clients', 'invoices', 'user_settings'];

    ClientModel client(String id, {String name = 'Medutech s.r.o.'}) => ClientModel(id: id, name: name, ico: '08975922', createdAt: DateTime(2026, 11, 1));

    ProjectClientModel link(String id, {String projectId = 'p1', String clientId = 'c1', DateTime? at}) =>
        ProjectClientModel(id: id, projectId: projectId, clientId: clientId, serviceDescription: 'Vývoj aplikace Artemis', createdAt: at ?? DateTime(2026, 11, 2));

    StandaloneInvoiceModel invoice(String id) => StandaloneInvoiceModel(
      id: id,
      invoiceNumber: 11,
      issueDate: DateTime(2026, 11, 30),
      dueDate: DateTime(2026, 12, 14),
      taxDate: DateTime(2026, 11, 30),
      customerJson: const {'name': 'Medutech s.r.o.'},
      lineItems: const [InvoiceLineItem(description: 'Vývoj aplikace Artemis', quantity: 58.75, unit: 'hod', unitPrice: 550)],
      createdAt: DateTime(2026, 11, 30),
      updatedAt: DateTime(2026, 11, 30),
      invoiceType: 'time_based',
      sourceProjectIds: const ['p1'],
      clientId: 'c1',
    );

    SupplierProfile profile(String name, DateTime updatedAt) => SupplierProfile(
      party: InvoiceParty(name: name, ico: '19164165'),
      iban: 'CZ00',
      updatedAt: updatedAt,
    );

    test('a server without the new collections still syncs everything else and keeps the new data queued', () async {
      server.missingCollections.addAll(newCollections);
      server.seed(_entries, remoteEntry('e1', notes: 'from server'));
      final service = createService();
      await clients.add(client('c1'));
      await service.pushClient(clients.getById('c1')!);
      await invoices.add(invoice('i1'));
      await service.pushInvoice(invoices.getById('i1')!);

      final result = await service.downloadAll();

      expect(result.error, isNull);
      expect(timeEntries.getById('e1')?.notes, 'from server');
      expect(clients.getById('c1')?.name, 'Medutech s.r.o.');
      expect(invoices.getById('i1')?.clientId, 'c1');
      expect(savedLedger().pendingOp('clients', 'c1'), PendingOp.upsert);
      expect(savedLedger().pendingOp('invoices', 'i1'), PendingOp.upsert);
    });

    test('queued data goes out once the server has the collections', () async {
      server.missingCollections.addAll(newCollections);
      final service = createService();
      await clients.add(client('c1'));
      await service.pushClient(clients.getById('c1')!);
      await projectClients.add(link('l1'));
      await service.pushProjectClient(projectClients.getById('l1')!);
      await invoices.add(invoice('i1'));
      await service.pushInvoice(invoices.getById('i1')!);

      server.missingCollections.clear();
      final result = await service.downloadAll();

      expect(result.error, isNull);
      expect(server.record('clients', 'c1')?['ico'], '08975922');
      expect(server.record('project_clients', 'l1')?['service_description'], 'Vývoj aplikace Artemis');
      expect(server.record('invoices', 'i1')?['client_id'], 'c1');
      expect(savedLedger().pendingCount, 0);
    });

    test('data from another device arrives intact, including the full invoice', () async {
      final source = createService();
      await clients.add(client('c1'));
      await source.pushClient(clients.getById('c1')!);
      await projectClients.add(link('l1'));
      await source.pushProjectClient(projectClients.getById('l1')!);
      await invoices.add(invoice('i1'));
      await source.pushInvoice(invoices.getById('i1')!);

      await clients.deleteAll();
      await projectClients.deleteAll();
      await invoices.deleteAll();
      await settings.setPocketBaseSyncLedger('');

      final result = await createService().downloadAll();

      expect(result.error, isNull);
      expect(clients.getById('c1'), client('c1'));
      expect(projectClients.getById('l1'), link('l1'));
      expect(invoices.getById('i1'), invoice('i1'));
    });

    test('the client the user put at the top of a project is offered first', () async {
      await projectClients.add(link('top', clientId: 'first', at: DateTime(2026, 1, 1)).copyWith(position: 0));
      await projectClients.add(link('below', clientId: 'second', at: DateTime(2026, 6, 1)).copyWith(position: 1));
      await projectClients.add(link('other', projectId: 'p2', clientId: 'third', at: DateTime(2026, 9, 1)).copyWith(position: 0));

      expect(projectClients.getByProject('p1').map((l) => l.clientId), ['first', 'second']);
      expect(projectClients.clientIdsForProjects(['p1', 'p2']), ['third', 'first', 'second']);
    });

    test('links without a position (all 0) fall back to the newest first', () async {
      await projectClients.add(link('old', clientId: 'first', at: DateTime(2026, 1, 1)));
      await projectClients.add(link('new', clientId: 'second', at: DateTime(2026, 6, 1)));

      expect(projectClients.clientIdsForProjects(['p1']), ['second', 'first']);
    });

    test('the order travels with the link through the server', () async {
      final source = createService();
      await projectClients.add(link('l1').copyWith(position: 2));
      await source.pushProjectClient(projectClients.getById('l1')!);
      await projectClients.deleteAll();
      await settings.setPocketBaseSyncLedger('');

      await createService().downloadAll();

      expect(projectClients.getById('l1')?.position, 2);
    });

    test('the supplier profile edited later wins in both directions', () async {
      server.seed('user_settings', {'item_id': 'supplier_profile', 'data': profile('Server', DateTime(2026, 11, 10)).toJson()});
      await settings.setSupplierProfile(profile('Older local', DateTime(2026, 11, 1)));

      await createService().downloadAll();
      expect(settings.getSupplierProfile()?.party.name, 'Server');

      await settings.setSupplierProfile(profile('Newer local', DateTime(2026, 11, 20)));
      await createService().downloadAll();
      expect(jsonDecode(jsonEncode(server.record('user_settings', 'supplier_profile')?['data']))['party']['name'], 'Newer local');
    });

    test('a local supplier profile the server does not have is uploaded, not dropped', () async {
      await settings.setSupplierProfile(profile('Only local', DateTime(2026, 11, 1)));

      final result = await createService().downloadAll();

      expect(result.error, isNull);
      expect(settings.getSupplierProfile()?.party.name, 'Only local');
      expect(server.record('user_settings', 'supplier_profile'), isNotNull);
    });
  });

  group('pomodoro', () {
    final t0 = DateTime(2026, 11, 24, 9);
    DateTime at(int minutes) => t0.add(Duration(minutes: minutes));
    const cfg = PomodoroSettings();

    PomodoroSession started(String id, int minute) => PomodoroEngine.start(id: id, settings: cfg, now: at(minute), startDevice: 'macOS');
    PomodoroLiveState live(PomodoroSession s, [List<String> ended = const []]) => PomodoroLiveState(session: s, endedSessionIds: ended, updatedAt: s.updatedAt);
    PomodoroLiveState? serverState() {
      final record = server.record('pomodoro_state', 'current');
      return record == null ? null : PomodoroLiveState.fromJson(jsonDecode(jsonEncode(record['data'])) as Map<String, dynamic>);
    }

    void seedState(PomodoroLiveState state) => server.seed('pomodoro_state', {'item_id': 'current', 'data': state.toJson()});

    test('a pushed state reaches the shared record', () async {
      await pomodoro.setLiveState(live(started('x', 0)));
      await createService().pushPomodoroState();
      expect(serverState()?.session?.id, 'x');
      expect(savedLedger().pendingCount, 0);
    });

    test('a stale device does not bring back a session ended elsewhere', () async {
      seedState(PomodoroLiveState(endedSessionIds: const ['x'], updatedAt: at(10)));
      await pomodoro.setLiveState(live(PomodoroEngine.skip(started('x', 0), cfg, at(15))));

      await createService().pushPomodoroState();

      expect(pomodoro.getLiveState().session, isNull);
      expect(serverState()?.session, isNull);
      expect(serverState()?.endedSessionIds, ['x']);
    });

    test('downloadAll takes a newer change made on another device', () async {
      final s = started('x', 0);
      await pomodoro.setLiveState(live(s));
      seedState(live(PomodoroEngine.pause(s, at(5))));

      final result = await createService().downloadAll();

      expect(result.error, isNull);
      expect(pomodoro.getSession()?.isPaused, isTrue);
    });

    test('two sessions started apart keep the later one and file the earlier one as replaced', () async {
      await pomodoro.setLiveState(live(started('a', 0)));
      seedState(live(started('b', 10)));

      await createService().downloadAll();

      expect(pomodoro.getSession()?.id, 'b');
      final record = pomodoro.getRecords().single;
      expect(record.id, 'a');
      expect(record.endReason, PomodoroEndReason.replaced);
      expect(record.endedAt, at(10));
      expect(record.workSeconds, 10 * 60);
      expect(serverState()?.session?.id, 'b');
      expect(serverState()?.endedSessionIds, ['a']);
    });

    test('a server without pomodoro_state syncs everything else and sends the state once it has it', () async {
      server.missingCollections.add('pomodoro_state');
      server.seed(_entries, remoteEntry('e1', notes: 'from server'));
      await pomodoro.setLiveState(live(started('x', 0)));
      final service = createService();
      await service.pushPomodoroState();

      final first = await service.downloadAll();
      expect(first.error, isNull);
      expect(timeEntries.getById('e1')?.notes, 'from server');
      expect(savedLedger().pendingOp('pomodoro_state', 'current'), PendingOp.upsert);
      expect(pomodoro.getSession()?.id, 'x');

      server.missingCollections.clear();
      final second = await service.downloadAll();
      expect(second.error, isNull);
      expect(serverState()?.session?.id, 'x');
      expect(savedLedger().pendingCount, 0);
    });

    test('pomodoro settings edited later win in both directions; untouched defaults are not uploaded', () async {
      await createService().downloadAll();
      expect(server.record('user_settings', 'pomodoro_settings'), isNull);

      server.seed('user_settings', {'item_id': 'pomodoro_settings', 'data': const PomodoroSettings(workMinutes: 50).copyWith(updatedAt: at(10)).toJson()});
      await pomodoro.setSettings(const PomodoroSettings(workMinutes: 30).copyWith(updatedAt: at(1)));
      await createService().downloadAll();
      expect(pomodoro.getSettings().workMinutes, 50);

      await pomodoro.setSettings(const PomodoroSettings(workMinutes: 40).copyWith(updatedAt: at(20)));
      await createService().downloadAll();
      expect(jsonDecode(jsonEncode(server.record('user_settings', 'pomodoro_settings')?['data']))['workMinutes'], 40);
    });

    test('pushPomodoroSettings and the supplier profile live side by side in user_settings', () async {
      await settings.setSupplierProfile(
        SupplierProfile(
          party: const InvoiceParty(name: 'Me'),
          updatedAt: at(0),
        ),
      );
      final service = createService();
      await service.pushSupplierProfile();
      await pomodoro.setSettings(const PomodoroSettings(shortBreakMinutes: 7).copyWith(updatedAt: at(1)));
      await service.pushPomodoroSettings();

      await createService().downloadAll();

      expect(server.records('user_settings'), hasLength(2));
      expect(settings.getSupplierProfile()?.party.name, 'Me');
      expect(pomodoro.getSettings().shortBreakMinutes, 7);
      expect(savedLedger().pendingCount, 0);
    });

    test('clearing local data drops the pomodoro but keeps the device preference', () async {
      await pomodoro.setLiveState(live(started('x', 0)));
      await pomodoro.setSettings(const PomodoroSettings(workMinutes: 50).copyWith(updatedAt: at(1)));
      await pomodoro.addRecord(PomodoroEngine.stop(started('old', 0), at(5)));
      await pomodoro.setShowOnTimeTracking(false);

      await createService().clearLocalData();

      expect(pomodoro.getLiveState(), PomodoroLiveState.empty);
      expect(pomodoro.getSettings(), const PomodoroSettings());
      expect(pomodoro.getRecords(), isEmpty);
      expect(pomodoro.getShowOnTimeTracking(), isFalse);
    });

    PomodoroSessionRecord finished(String id, int minute) => PomodoroEngine.stop(started(id, 0), at(minute));

    test('a finished session reaches the server and another device downloads it', () async {
      final record = finished('r1', 30);
      await pomodoro.addRecord(record);
      await createService().pushPomodoroRecord(record);
      expect(server.record('pomodoro_sessions', 'r1'), isNotNull);

      await pomodoro.clearAccountData();
      await settings.setPocketBaseSyncLedger('');
      await createService().downloadAll();
      expect(pomodoro.getRecord('r1'), record);
    });

    test('a session deleted on another device disappears; one never uploaded is sent instead of dropped', () async {
      final kept = finished('kept', 30);
      final deletedElsewhere = finished('gone', 40);
      final service = createService();
      for (final r in [kept, deletedElsewhere]) {
        await pomodoro.addRecord(r);
        await service.pushPomodoroRecord(r);
      }
      server.remove('pomodoro_sessions', 'gone');
      final offline = finished('offline', 50);
      await pomodoro.addRecord(offline);

      final result = await service.downloadAll();

      expect(result.error, isNull);
      expect(pomodoro.getRecord('gone'), isNull);
      expect(pomodoro.getRecord('kept'), kept);
      expect(server.record('pomodoro_sessions', 'offline'), isNotNull);
    });

    test('deleting a session removes it from the server', () async {
      final record = finished('r1', 30);
      await pomodoro.addRecord(record);
      final service = createService();
      await service.pushPomodoroRecord(record);
      await pomodoro.deleteRecord('r1');
      await service.deletePomodoroRecord('r1');
      expect(server.record('pomodoro_sessions', 'r1'), isNull);
    });

    test('a full upload never deletes server sessions this device lacks', () async {
      server.seed('pomodoro_sessions', {'item_id': 'other-device', 'data': finished('other-device', 20).toJson()});
      await pomodoro.addRecord(finished('mine', 30));

      final result = await createService().uploadAll();

      expect(result.error, isNull);
      expect(server.record('pomodoro_sessions', 'other-device'), isNotNull);
      expect(server.record('pomodoro_sessions', 'mine'), isNotNull);
    });
  });
}
