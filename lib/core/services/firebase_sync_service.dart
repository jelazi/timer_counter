import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/models/category_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';

/// Callback for reporting sync progress.
typedef SyncProgressCallback = void Function(String message, double progress);

/// Result of a sync operation.
class SyncResult {
  final int projectsSynced;
  final int tasksSynced;
  final int timeEntriesSynced;
  final int categoriesSynced;
  final String? error;

  const SyncResult({this.projectsSynced = 0, this.tasksSynced = 0, this.timeEntriesSynced = 0, this.categoriesSynced = 0, this.error});

  bool get hasError => error != null;
  int get total => projectsSynced + tasksSynced + timeEntriesSynced + categoriesSynced;
}

/// Service for synchronizing all app data with Firebase Firestore via REST API.
///
/// Uses the Firestore REST API directly (no native Firebase SDK needed).
/// The user provides their Firebase Project ID and API Key.
///
/// Firestore security rules should allow read/write access for the API key.
/// For a personal app, rules like `allow read, write: if true;` work.
class FirebaseSyncService {
  final String projectId;
  final String apiKey;
  final ProjectRepository projectRepo;
  final TaskRepository taskRepo;
  final TimeEntryRepository timeEntryRepo;
  final CategoryRepository categoryRepo;

  FirebaseSyncService({required this.projectId, required this.apiKey, required this.projectRepo, required this.taskRepo, required this.timeEntryRepo, required this.categoryRepo});

  /// Firestore document resource name prefix.
  String get _docBase => 'projects/$projectId/databases/(default)/documents';

  /// Firestore REST API URL base.
  String get _urlBase => 'https://firestore.googleapis.com/v1/$_docBase';

  /// Full document resource name for batch writes.
  String _docName(String collection, String docId) => '$_docBase/$collection/$docId';

  // ======================================================================
  // PUBLIC API
  // ======================================================================

  /// Test whether the Firebase connection works.
  Future<bool> testConnection() async {
    try {
      final uri = Uri.parse('$_urlBase/projects').replace(queryParameters: {'pageSize': '1', 'key': apiKey});
      final response = await http.get(uri);
      // 200 = OK (collection exists or empty)
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Upload all local data to Firebase, replacing remote data entirely.
  Future<SyncResult> uploadAll({SyncProgressCallback? onProgress}) async {
    try {
      onProgress?.call('Categories…', 0.05);
      final categories = categoryRepo.getAll();
      await _replaceRemoteCollection('categories', {for (final c in categories) c.id: _categoryToFields(c)});

      onProgress?.call('Projects…', 0.25);
      final projects = projectRepo.getAll();
      await _replaceRemoteCollection('projects', {for (final p in projects) p.id: _projectToFields(p)});

      onProgress?.call('Tasks…', 0.50);
      final tasks = taskRepo.getAll();
      await _replaceRemoteCollection('tasks', {for (final t in tasks) t.id: _taskToFields(t)});

      onProgress?.call('Time entries…', 0.75);
      final entries = timeEntryRepo.getAll();
      await _replaceRemoteCollection('time_entries', {for (final e in entries) e.id: _timeEntryToFields(e)});

      onProgress?.call('Done', 1.0);
      return SyncResult(categoriesSynced: categories.length, projectsSynced: projects.length, tasksSynced: tasks.length, timeEntriesSynced: entries.length);
    } catch (e) {
      return SyncResult(error: e.toString());
    }
  }

  /// Download all data from Firebase, replacing local data entirely.
  Future<SyncResult> downloadAll({SyncProgressCallback? onProgress}) async {
    try {
      onProgress?.call('Categories…', 0.05);
      final remoteCategories = await _fetchRemote('categories', _categoryFromFields);
      await _replaceLocalCollection(
        remoteCategories,
        getLocalIds: () => categoryRepo.getAll().map((c) => c.id).toSet(),
        upsert: (c) => categoryRepo.add(c),
        delete: (id) => categoryRepo.delete(id),
        getId: (c) => c.id,
      );

      onProgress?.call('Projects…', 0.25);
      final remoteProjects = await _fetchRemote('projects', _projectFromFields);
      await _replaceLocalCollection(
        remoteProjects,
        getLocalIds: () => projectRepo.getAll().map((p) => p.id).toSet(),
        upsert: (p) => projectRepo.add(p),
        delete: (id) => projectRepo.delete(id),
        getId: (p) => p.id,
      );

      onProgress?.call('Tasks…', 0.50);
      final remoteTasks = await _fetchRemote('tasks', _taskFromFields);
      await _replaceLocalCollection(
        remoteTasks,
        getLocalIds: () => taskRepo.getAll().map((t) => t.id).toSet(),
        upsert: (t) => taskRepo.add(t),
        delete: (id) => taskRepo.delete(id),
        getId: (t) => t.id,
      );

      onProgress?.call('Time entries…', 0.75);
      final remoteEntries = await _fetchRemote('time_entries', _timeEntryFromFields);
      await _replaceLocalCollection(
        remoteEntries,
        getLocalIds: () => timeEntryRepo.getAll().map((e) => e.id).toSet(),
        upsert: (e) => timeEntryRepo.add(e),
        delete: (id) => timeEntryRepo.delete(id),
        getId: (e) => e.id,
      );

      onProgress?.call('Done', 1.0);
      return SyncResult(categoriesSynced: remoteCategories.length, projectsSynced: remoteProjects.length, tasksSynced: remoteTasks.length, timeEntriesSynced: remoteEntries.length);
    } catch (e) {
      return SyncResult(error: e.toString());
    }
  }

  /// Bidirectional merge: union of local + remote, conflicts resolved by createdAt.
  Future<SyncResult> syncAll({SyncProgressCallback? onProgress}) async {
    try {
      onProgress?.call('Categories…', 0.05);
      final cSync = await _mergeCollection<CategoryModel>(
        collection: 'categories',
        localItems: categoryRepo.getAll(),
        getId: (c) => c.id,
        getCreatedAt: (c) => c.createdAt,
        toFields: _categoryToFields,
        fromFields: _categoryFromFields,
        upsert: (c) => categoryRepo.add(c),
      );

      onProgress?.call('Projects…', 0.25);
      final pSync = await _mergeCollection<ProjectModel>(
        collection: 'projects',
        localItems: projectRepo.getAll(),
        getId: (p) => p.id,
        getCreatedAt: (p) => p.createdAt,
        toFields: _projectToFields,
        fromFields: _projectFromFields,
        upsert: (p) => projectRepo.add(p),
      );

      onProgress?.call('Tasks…', 0.50);
      final tSync = await _mergeCollection<TaskModel>(
        collection: 'tasks',
        localItems: taskRepo.getAll(),
        getId: (t) => t.id,
        getCreatedAt: (t) => t.createdAt,
        toFields: _taskToFields,
        fromFields: _taskFromFields,
        upsert: (t) => taskRepo.add(t),
      );

      onProgress?.call('Time entries…', 0.75);
      final eSync = await _mergeCollection<TimeEntryModel>(
        collection: 'time_entries',
        localItems: timeEntryRepo.getAll(),
        getId: (e) => e.id,
        getCreatedAt: (e) => e.createdAt,
        toFields: _timeEntryToFields,
        fromFields: _timeEntryFromFields,
        upsert: (e) => timeEntryRepo.add(e),
      );

      onProgress?.call('Done', 1.0);
      return SyncResult(categoriesSynced: cSync, projectsSynced: pSync, tasksSynced: tSync, timeEntriesSynced: eSync);
    } catch (e) {
      return SyncResult(error: e.toString());
    }
  }

  // ======================================================================
  // COLLECTION-LEVEL HELPERS
  // ======================================================================

  /// Replace remote collection with [localItems]. Deletes remote orphans.
  Future<void> _replaceRemoteCollection(String collection, Map<String, Map<String, dynamic>> localItems) async {
    final remoteDocs = await _listCollection(collection);
    final remoteIds = remoteDocs.map((d) => _extractDocId(d['name'] as String)).toSet();

    final writes = <Map<String, dynamic>>[];
    for (final entry in localItems.entries) {
      writes.add({
        'update': {'name': _docName(collection, entry.key), 'fields': entry.value},
      });
    }
    for (final rid in remoteIds) {
      if (!localItems.containsKey(rid)) {
        writes.add({'delete': _docName(collection, rid)});
      }
    }
    await _batchWrite(writes);
  }

  /// Replace local collection with [remoteItems]. Deletes local orphans.
  Future<void> _replaceLocalCollection<T>(
    List<T> remoteItems, {
    required Set<String> Function() getLocalIds,
    required Future<void> Function(T) upsert,
    required Future<void> Function(String) delete,
    required String Function(T) getId,
  }) async {
    final remoteIds = <String>{};
    for (final item in remoteItems) {
      remoteIds.add(getId(item));
      await upsert(item);
    }
    final localIds = getLocalIds();
    for (final lid in localIds) {
      if (!remoteIds.contains(lid)) {
        await delete(lid);
      }
    }
  }

  /// Merge local + remote (union). Returns count of items in merged set.
  Future<int> _mergeCollection<T>({
    required String collection,
    required List<T> localItems,
    required String Function(T) getId,
    required DateTime Function(T) getCreatedAt,
    required Map<String, dynamic> Function(T) toFields,
    required T Function(Map<String, dynamic>) fromFields,
    required Future<void> Function(T) upsert,
  }) async {
    // Build local map
    final localMap = <String, T>{};
    for (final item in localItems) {
      localMap[getId(item)] = item;
    }

    // Build remote map
    final remoteItems = await _fetchRemote(collection, fromFields);
    final remoteMap = <String, T>{};
    for (final item in remoteItems) {
      remoteMap[getId(item)] = item;
    }

    // Merge: union, conflicts → newer wins
    final merged = <String, T>{};
    final allIds = {...localMap.keys, ...remoteMap.keys};
    for (final id in allIds) {
      final local = localMap[id];
      final remote = remoteMap[id];
      if (local != null && remote == null) {
        merged[id] = local;
      } else if (local == null && remote != null) {
        merged[id] = remote;
      } else if (local != null && remote != null) {
        merged[id] = getCreatedAt(local).isAfter(getCreatedAt(remote)) ? local : remote;
      }
    }

    // Write merged to local
    for (final item in merged.values) {
      await upsert(item);
    }

    // Write merged to remote
    final writes = <Map<String, dynamic>>[];
    for (final entry in merged.entries) {
      writes.add({
        'update': {'name': _docName(collection, entry.key), 'fields': toFields(entry.value)},
      });
    }
    await _batchWrite(writes);

    return merged.length;
  }

  // ======================================================================
  // FIRESTORE REST HELPERS
  // ======================================================================

  /// List all documents in a Firestore collection (handles pagination).
  Future<List<Map<String, dynamic>>> _listCollection(String collection) async {
    final docs = <Map<String, dynamic>>[];
    String? pageToken;

    do {
      final params = <String, String>{'pageSize': '1000', 'key': apiKey};
      if (pageToken != null) params['pageToken'] = pageToken;

      final uri = Uri.parse('$_urlBase/$collection').replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 404) break;
      if (response.statusCode != 200) {
        throw Exception('Firestore list $collection failed: ${response.statusCode} — ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final documents = data['documents'] as List?;
      if (documents != null) {
        docs.addAll(documents.cast<Map<String, dynamic>>());
      }

      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);

    return docs;
  }

  /// Fetch collection as parsed model objects.
  Future<List<T>> _fetchRemote<T>(String collection, T Function(Map<String, dynamic>) fromFields) async {
    final docs = await _listCollection(collection);
    return docs.map((doc) {
      final fields = (doc['fields'] as Map<String, dynamic>?) ?? {};
      return fromFields(fields.cast<String, dynamic>());
    }).toList();
  }

  /// Execute batch writes (auto-chunked to 500 per request).
  Future<void> _batchWrite(List<Map<String, dynamic>> writes) async {
    if (writes.isEmpty) return;

    final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:batchWrite';
    for (var i = 0; i < writes.length; i += 500) {
      final end = (i + 500).clamp(0, writes.length);
      final batch = writes.sublist(i, end);

      final response = await http.post(
        Uri.parse(url).replace(queryParameters: {'key': apiKey}),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'writes': batch}),
      );

      if (response.statusCode != 200) {
        throw Exception('Firestore batchWrite failed: ${response.statusCode} — ${response.body}');
      }
    }
  }

  /// Extract document ID from full resource name.
  String _extractDocId(String name) => name.split('/').last;

  // ======================================================================
  // FIRESTORE VALUE CONVERSION
  // ======================================================================

  static Map<String, dynamic> _fv(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is String) return {'stringValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is DateTime) return {'timestampValue': value.toUtc().toIso8601String()};
    return {'stringValue': value.toString()};
  }

  static String? _rvString(Map<String, dynamic>? v) {
    if (v == null) return null;
    if (v.containsKey('stringValue')) return v['stringValue'] as String;
    if (v.containsKey('nullValue')) return null;
    return null;
  }

  static int _rvInt(Map<String, dynamic>? v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v.containsKey('integerValue')) {
      final raw = v['integerValue'];
      return raw is int ? raw : int.parse(raw.toString());
    }
    if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toInt();
    return fallback;
  }

  static double _rvDouble(Map<String, dynamic>? v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
    if (v.containsKey('integerValue')) {
      final raw = v['integerValue'];
      return raw is num ? raw.toDouble() : double.parse(raw.toString());
    }
    return fallback;
  }

  static bool _rvBool(Map<String, dynamic>? v, [bool fallback = false]) {
    if (v == null) return fallback;
    if (v.containsKey('booleanValue')) return v['booleanValue'] as bool;
    return fallback;
  }

  static DateTime _rvDateTime(Map<String, dynamic>? v, [DateTime? fallback]) {
    if (v != null && v.containsKey('timestampValue')) {
      return DateTime.parse(v['timestampValue'] as String);
    }
    return fallback ?? DateTime.now();
  }

  static DateTime? _rvDateTimeOrNull(Map<String, dynamic>? v) {
    if (v == null) return null;
    if (v.containsKey('timestampValue')) return DateTime.parse(v['timestampValue'] as String);
    if (v.containsKey('nullValue')) return null;
    return null;
  }

  // ======================================================================
  // MODEL ↔ FIRESTORE FIELDS CONVERSIONS
  // ======================================================================

  // --- Category ---
  static Map<String, dynamic> _categoryToFields(CategoryModel c) => {'id': _fv(c.id), 'name': _fv(c.name), 'colorValue': _fv(c.colorValue), 'createdAt': _fv(c.createdAt)};

  static CategoryModel _categoryFromFields(Map<String, dynamic> f) => CategoryModel(
    id: _rvString(f['id'] as Map<String, dynamic>?) ?? '',
    name: _rvString(f['name'] as Map<String, dynamic>?) ?? '',
    colorValue: _rvInt(f['colorValue'] as Map<String, dynamic>?),
    createdAt: _rvDateTime(f['createdAt'] as Map<String, dynamic>?),
  );

  // --- Project ---
  static Map<String, dynamic> _projectToFields(ProjectModel p) {
    final fields = <String, dynamic>{
      'id': _fv(p.id),
      'name': _fv(p.name),
      'colorValue': _fv(p.colorValue),
      'hourlyRate': _fv(p.hourlyRate),
      'plannedTimeHours': _fv(p.plannedTimeHours),
      'plannedBudget': _fv(p.plannedBudget),
      'notes': _fv(p.notes),
      'isArchived': _fv(p.isArchived),
      'isBillable': _fv(p.isBillable),
      'createdAt': _fv(p.createdAt),
    };
    if (p.categoryId != null) fields['categoryId'] = _fv(p.categoryId);
    if (p.startDate != null) fields['startDate'] = _fv(p.startDate);
    if (p.dueDate != null) fields['dueDate'] = _fv(p.dueDate);
    return fields;
  }

  static ProjectModel _projectFromFields(Map<String, dynamic> f) => ProjectModel(
    id: _rvString(f['id'] as Map<String, dynamic>?) ?? '',
    name: _rvString(f['name'] as Map<String, dynamic>?) ?? '',
    categoryId: _rvString(f['categoryId'] as Map<String, dynamic>?),
    colorValue: _rvInt(f['colorValue'] as Map<String, dynamic>?),
    hourlyRate: _rvDouble(f['hourlyRate'] as Map<String, dynamic>?),
    plannedTimeHours: _rvDouble(f['plannedTimeHours'] as Map<String, dynamic>?),
    plannedBudget: _rvDouble(f['plannedBudget'] as Map<String, dynamic>?),
    startDate: _rvDateTimeOrNull(f['startDate'] as Map<String, dynamic>?),
    dueDate: _rvDateTimeOrNull(f['dueDate'] as Map<String, dynamic>?),
    notes: _rvString(f['notes'] as Map<String, dynamic>?) ?? '',
    isArchived: _rvBool(f['isArchived'] as Map<String, dynamic>?),
    isBillable: _rvBool(f['isBillable'] as Map<String, dynamic>?, true),
    createdAt: _rvDateTime(f['createdAt'] as Map<String, dynamic>?),
  );

  // --- Task ---
  static Map<String, dynamic> _taskToFields(TaskModel t) {
    final fields = <String, dynamic>{
      'id': _fv(t.id),
      'projectId': _fv(t.projectId),
      'name': _fv(t.name),
      'isBillable': _fv(t.isBillable),
      'notes': _fv(t.notes),
      'isArchived': _fv(t.isArchived),
      'createdAt': _fv(t.createdAt),
      'colorValue': _fv(t.colorValue),
    };
    if (t.hourlyRate != null) fields['hourlyRate'] = _fv(t.hourlyRate);
    return fields;
  }

  static TaskModel _taskFromFields(Map<String, dynamic> f) => TaskModel(
    id: _rvString(f['id'] as Map<String, dynamic>?) ?? '',
    projectId: _rvString(f['projectId'] as Map<String, dynamic>?) ?? '',
    name: _rvString(f['name'] as Map<String, dynamic>?) ?? '',
    hourlyRate: f.containsKey('hourlyRate') ? _rvDouble(f['hourlyRate'] as Map<String, dynamic>?) : null,
    isBillable: _rvBool(f['isBillable'] as Map<String, dynamic>?, true),
    notes: _rvString(f['notes'] as Map<String, dynamic>?) ?? '',
    isArchived: _rvBool(f['isArchived'] as Map<String, dynamic>?),
    createdAt: _rvDateTime(f['createdAt'] as Map<String, dynamic>?),
    colorValue: _rvInt(f['colorValue'] as Map<String, dynamic>?, 0xFF6366F1),
  );

  // --- TimeEntry ---
  static Map<String, dynamic> _timeEntryToFields(TimeEntryModel e) {
    final fields = <String, dynamic>{
      'id': _fv(e.id),
      'projectId': _fv(e.projectId),
      'taskId': _fv(e.taskId),
      'startTime': _fv(e.startTime),
      'durationSeconds': _fv(e.durationSeconds),
      'notes': _fv(e.notes),
      'createdAt': _fv(e.createdAt),
      'isBillable': _fv(e.isBillable),
    };
    if (e.endTime != null) fields['endTime'] = _fv(e.endTime);
    return fields;
  }

  static TimeEntryModel _timeEntryFromFields(Map<String, dynamic> f) => TimeEntryModel(
    id: _rvString(f['id'] as Map<String, dynamic>?) ?? '',
    projectId: _rvString(f['projectId'] as Map<String, dynamic>?) ?? '',
    taskId: _rvString(f['taskId'] as Map<String, dynamic>?) ?? '',
    startTime: _rvDateTime(f['startTime'] as Map<String, dynamic>?),
    endTime: _rvDateTimeOrNull(f['endTime'] as Map<String, dynamic>?),
    durationSeconds: _rvInt(f['durationSeconds'] as Map<String, dynamic>?),
    notes: _rvString(f['notes'] as Map<String, dynamic>?) ?? '',
    createdAt: _rvDateTime(f['createdAt'] as Map<String, dynamic>?),
    isBillable: _rvBool(f['isBillable'] as Map<String, dynamic>?, true),
  );
}
