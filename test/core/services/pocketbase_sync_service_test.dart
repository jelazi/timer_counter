import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timer_counter/core/services/pocketbase_sync_service.dart';
import 'package:timer_counter/core/services/sync_ledger.dart';
import 'package:timer_counter/data/models/category_model.dart';
import 'package:timer_counter/data/models/monthly_hours_target_model.dart';
import 'package:timer_counter/data/models/project_model.dart';
import 'package:timer_counter/data/models/running_timer_model.dart';
import 'package:timer_counter/data/models/task_model.dart';
import 'package:timer_counter/data/models/time_entry_model.dart';
import 'package:timer_counter/data/repositories/category_repository.dart';
import 'package:timer_counter/data/repositories/monthly_hours_target_repository.dart';
import 'package:timer_counter/data/repositories/project_repository.dart';
import 'package:timer_counter/data/repositories/running_timer_repository.dart';
import 'package:timer_counter/data/repositories/settings_repository.dart';
import 'package:timer_counter/data/repositories/task_repository.dart';
import 'package:timer_counter/data/repositories/time_entry_repository.dart';

const _userId = 'user1';
const _entries = 'time_entries';

class FakePocketBase {
  final Map<String, Map<String, Map<String, dynamic>>> _collections = {};
  int _nextId = 0;

  bool rejectWrites = false;

  void seed(String collection, Map<String, dynamic> fields) {
    final id = 'pb${_nextId++}';
    (_collections[collection] ??= {})[id] = {'id': id, 'collectionName': collection, 'user': _userId, ...fields};
  }

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

  static http.Response _json(int status, Map<String, dynamic> body) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
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

  setUpAll(() {
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(ProjectModelAdapter());
    Hive.registerAdapter(TaskModelAdapter());
    Hive.registerAdapter(TimeEntryModelAdapter());
    Hive.registerAdapter(RunningTimerModelAdapter());
    Hive.registerAdapter(MonthlyHoursTargetModelAdapter());
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
    for (final init in [settings.init, timeEntries.init, categories.init, projects.init, tasks.init, runningTimers.init, monthlyTargets.init]) {
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
    httpClientFactory: server.client,
  );

  TimeEntryModel entry(String id, {String notes = ''}) => TimeEntryModel(
    id: id,
    projectId: 'p1',
    taskId: 't1',
    startTime: DateTime(2026, 10, 1, 8),
    endTime: DateTime(2026, 10, 1, 9),
    notes: notes,
    createdAt: DateTime(2026, 10, 1),
  );

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
}
