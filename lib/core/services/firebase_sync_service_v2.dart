import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/category_model.dart';
import '../../data/models/monthly_hours_target_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/running_timer_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/monthly_hours_target_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/running_timer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums & Result types
// ─────────────────────────────────────────────────────────────────────────────

enum SyncStatus { disabled, connecting, connected, error }

/// Event emitted when a remote change updates a local collection.
enum SyncCollection { categories, projects, tasks, timeEntries, runningTimers, monthlyTargets }

/// Callback for reporting sync progress.
typedef SyncProgressCallback = void Function(String message, double progress);

/// Result of a sync operation.
class SyncResult {
  final int projectsSynced;
  final int tasksSynced;
  final int timeEntriesSynced;
  final int categoriesSynced;
  final int runningTimersSynced;
  final int monthlyTargetsSynced;
  final String? error;

  const SyncResult({
    this.projectsSynced = 0,
    this.tasksSynced = 0,
    this.timeEntriesSynced = 0,
    this.categoriesSynced = 0,
    this.runningTimersSynced = 0,
    this.monthlyTargetsSynced = 0,
    this.error,
  });

  bool get hasError => error != null;
  int get total => projectsSynced + tasksSynced + timeEntriesSynced + categoriesSynced + runningTimersSynced + monthlyTargetsSynced;
}

// ─────────────────────────────────────────────────────────────────────────────
// FirebaseSyncService — Cloud Firestore SDK with real-time listeners
// ─────────────────────────────────────────────────────────────────────────────

class FirebaseSyncService {
  final CategoryRepository _categoryRepo;
  final ProjectRepository _projectRepo;
  final TaskRepository _taskRepo;
  final TimeEntryRepository _timeEntryRepo;
  final RunningTimerRepository _runningTimerRepo;
  final MonthlyHoursTargetRepository _monthlyTargetRepo;
  final SettingsRepository _settingsRepo;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  final _collectionChangeController = StreamController<SyncCollection>.broadcast();

  /// Emitted when a Firestore snapshot updates a local Hive collection.
  Stream<SyncCollection> get onCollectionChanged => _collectionChangeController.stream;

  SyncStatus _currentStatus = SyncStatus.disabled;
  SyncStatus get currentStatus => _currentStatus;

  final List<StreamSubscription> _listeners = [];
  bool _listenersActive = false;

  /// Suppresses local updates from Firestore listeners during bulk operations.
  bool _suppressListeners = false;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  String? get userId => currentUser?.uid;

  FirebaseSyncService({
    required CategoryRepository categoryRepo,
    required ProjectRepository projectRepo,
    required TaskRepository taskRepo,
    required TimeEntryRepository timeEntryRepo,
    required RunningTimerRepository runningTimerRepo,
    required MonthlyHoursTargetRepository monthlyTargetRepo,
    required SettingsRepository settingsRepo,
  }) : _categoryRepo = categoryRepo,
       _projectRepo = projectRepo,
       _taskRepo = taskRepo,
       _timeEntryRepo = timeEntryRepo,
       _runningTimerRepo = runningTimerRepo,
       _monthlyTargetRepo = monthlyTargetRepo,
       _settingsRepo = settingsRepo;

  // ═════════════════════════════════════════════════════════════════════════
  // Firestore path helpers
  // ═════════════════════════════════════════════════════════════════════════

  CollectionReference<Map<String, dynamic>> _col(String name) => _firestore.collection('users/${currentUser!.uid}/$name');

  DocumentReference<Map<String, dynamic>> _doc(String col, String docId) => _firestore.collection('users/${currentUser!.uid}/$col').doc(docId);

  // ═════════════════════════════════════════════════════════════════════════
  // Authentication
  // ═════════════════════════════════════════════════════════════════════════

  /// Sign up with email/password. Returns null on success, error message on failure.
  Future<String?> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with email/password. Returns null on success, error message on failure.
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign out and stop all listeners.
  Future<void> signOut() async {
    await stopListeners();
    await _auth.signOut();
    _setStatus(SyncStatus.disabled);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Listener management — real-time sync
  // ═════════════════════════════════════════════════════════════════════════

  /// Start real-time Firestore listeners for all collections.
  /// Must be signed in first.
  void startListeners() {
    if (!isSignedIn || _listenersActive) return;
    _listenersActive = true;
    _setStatus(SyncStatus.connecting);

    _listeners.add(_listenCategories());
    _listeners.add(_listenProjects());
    _listeners.add(_listenTasks());
    _listeners.add(_listenTimeEntries());
    _listeners.add(_listenRunningTimers());
    _listeners.add(_listenMonthlyTargets());

    _setStatus(SyncStatus.connected);
    debugPrint('[FirebaseSync] Real-time listeners started for user $userId');
  }

  /// Stop all Firestore listeners.
  Future<void> stopListeners() async {
    for (final sub in _listeners) {
      await sub.cancel();
    }
    _listeners.clear();
    _listenersActive = false;
    debugPrint('[FirebaseSync] Listeners stopped');
  }

  void _setStatus(SyncStatus s) {
    _currentStatus = s;
    _statusController.add(s);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PUSH — write single document to Firestore
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> pushCategory(CategoryModel c) async {
    if (!isSignedIn) return;
    await _doc('categories', c.id).set(_categoryToMap(c));
  }

  Future<void> deleteCategory(String id) async {
    if (!isSignedIn) return;
    await _doc('categories', id).delete();
  }

  Future<void> pushProject(ProjectModel p) async {
    if (!isSignedIn) return;
    await _doc('projects', p.id).set(_projectToMap(p));
  }

  Future<void> deleteProject(String id) async {
    if (!isSignedIn) return;
    await _doc('projects', id).delete();
  }

  Future<void> pushTask(TaskModel t) async {
    if (!isSignedIn) return;
    await _doc('tasks', t.id).set(_taskToMap(t));
  }

  Future<void> deleteTask(String id) async {
    if (!isSignedIn) return;
    await _doc('tasks', id).delete();
  }

  Future<void> pushTimeEntry(TimeEntryModel e) async {
    if (!isSignedIn) return;
    await _doc('time_entries', e.id).set(_timeEntryToMap(e));
  }

  Future<void> deleteTimeEntry(String id) async {
    if (!isSignedIn) return;
    await _doc('time_entries', id).delete();
  }

  Future<void> pushRunningTimer(RunningTimerModel t) async {
    if (!isSignedIn) return;
    await _doc('running_timers', t.id).set(_runningTimerToMap(t));
  }

  Future<void> deleteRunningTimer(String id) async {
    if (!isSignedIn) return;
    await _doc('running_timers', id).delete();
  }

  Future<void> pushMonthlyTarget(MonthlyHoursTargetModel m) async {
    if (!isSignedIn) return;
    await _doc('monthly_targets', m.id).set(_monthlyTargetToMap(m));
  }

  Future<void> deleteMonthlyTarget(String id) async {
    if (!isSignedIn) return;
    await _doc('monthly_targets', id).delete();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BULK — initial upload / download
  // ═════════════════════════════════════════════════════════════════════════

  /// Upload all local data to Firestore, replacing remote.
  Future<SyncResult> uploadAll({SyncProgressCallback? onProgress}) async {
    if (!isSignedIn) return const SyncResult(error: 'Not signed in');
    _suppressListeners = true;
    try {
      onProgress?.call('Categories…', 0.05);
      final categories = _categoryRepo.getAll();
      await _replaceRemote('categories', {for (final c in categories) c.id: _categoryToMap(c)});

      onProgress?.call('Projects…', 0.15);
      final projects = _projectRepo.getAll();
      await _replaceRemote('projects', {for (final p in projects) p.id: _projectToMap(p)});

      onProgress?.call('Tasks…', 0.30);
      final tasks = _taskRepo.getAll();
      await _replaceRemote('tasks', {for (final t in tasks) t.id: _taskToMap(t)});

      onProgress?.call('Time entries…', 0.50);
      final entries = _timeEntryRepo.getAll();
      await _replaceRemote('time_entries', {for (final e in entries) e.id: _timeEntryToMap(e)});

      onProgress?.call('Running timers…', 0.75);
      final timers = _runningTimerRepo.getAll();
      await _replaceRemote('running_timers', {for (final t in timers) t.id: _runningTimerToMap(t)});

      onProgress?.call('Monthly targets…', 0.90);
      final targets = _monthlyTargetRepo.getAll();
      await _replaceRemote('monthly_targets', {for (final m in targets) m.id: _monthlyTargetToMap(m)});

      _settingsRepo.setFirebaseLastSync(DateTime.now().toIso8601String());
      onProgress?.call('Done', 1.0);
      return SyncResult(
        categoriesSynced: categories.length,
        projectsSynced: projects.length,
        tasksSynced: tasks.length,
        timeEntriesSynced: entries.length,
        runningTimersSynced: timers.length,
        monthlyTargetsSynced: targets.length,
      );
    } catch (e) {
      return SyncResult(error: e.toString());
    } finally {
      _suppressListeners = false;
    }
  }

  /// Download all remote data, replacing local.
  Future<SyncResult> downloadAll({SyncProgressCallback? onProgress}) async {
    if (!isSignedIn) return const SyncResult(error: 'Not signed in');
    _suppressListeners = true;
    try {
      onProgress?.call('Categories…', 0.05);
      final cats = await _downloadCollection('categories', _categoryFromMap);
      await _replaceLocal<CategoryModel>(cats, _categoryRepo.getAll().map((c) => c.id).toSet(), (c) => _categoryRepo.add(c), (id) => _categoryRepo.delete(id), (c) => c.id);

      onProgress?.call('Projects…', 0.15);
      final projs = await _downloadCollection('projects', _projectFromMap);
      await _replaceLocal<ProjectModel>(projs, _projectRepo.getAll().map((p) => p.id).toSet(), (p) => _projectRepo.add(p), (id) => _projectRepo.delete(id), (p) => p.id);

      onProgress?.call('Tasks…', 0.30);
      final tasks = await _downloadCollection('tasks', _taskFromMap);
      await _replaceLocal<TaskModel>(tasks, _taskRepo.getAll().map((t) => t.id).toSet(), (t) => _taskRepo.add(t), (id) => _taskRepo.delete(id), (t) => t.id);

      onProgress?.call('Time entries…', 0.50);
      final entries = await _downloadCollection('time_entries', _timeEntryFromMap);
      await _replaceLocal<TimeEntryModel>(entries, _timeEntryRepo.getAll().map((e) => e.id).toSet(), (e) => _timeEntryRepo.add(e), (id) => _timeEntryRepo.delete(id), (e) => e.id);

      onProgress?.call('Running timers…', 0.75);
      final timers = await _downloadCollection('running_timers', _runningTimerFromMap);
      await _replaceLocal<RunningTimerModel>(
        timers,
        _runningTimerRepo.getAll().map((t) => t.id).toSet(),
        (t) => _runningTimerRepo.start(t),
        (id) => _runningTimerRepo.stop(id),
        (t) => t.id,
      );

      onProgress?.call('Monthly targets…', 0.90);
      final targets = await _downloadCollection('monthly_targets', _monthlyTargetFromMap);
      await _replaceLocal<MonthlyHoursTargetModel>(
        targets,
        _monthlyTargetRepo.getAll().map((m) => m.id).toSet(),
        (m) => _monthlyTargetRepo.add(m),
        (id) => _monthlyTargetRepo.delete(id),
        (m) => m.id,
      );

      _settingsRepo.setFirebaseLastSync(DateTime.now().toIso8601String());
      onProgress?.call('Done', 1.0);
      return SyncResult(
        categoriesSynced: cats.length,
        projectsSynced: projs.length,
        tasksSynced: tasks.length,
        timeEntriesSynced: entries.length,
        runningTimersSynced: timers.length,
        monthlyTargetsSynced: targets.length,
      );
    } catch (e) {
      return SyncResult(error: e.toString());
    } finally {
      _suppressListeners = false;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Real-time listeners — Firestore → Hive
  // ═════════════════════════════════════════════════════════════════════════

  StreamSubscription _listenCategories() {
    return _col('categories').snapshots().listen((snap) {
      if (_suppressListeners) return;
      _applyChanges<CategoryModel>(
        snap,
        _categoryFromMap,
        (c) => c.id,
        _categoryRepo.getAll().map((c) => c.id).toSet(),
        (c) => _categoryRepo.add(c),
        (id) => _categoryRepo.delete(id),
      );
      _collectionChangeController.add(SyncCollection.categories);
    }, onError: (e) => debugPrint('[FirebaseSync] categories error: $e'));
  }

  StreamSubscription _listenProjects() {
    return _col('projects').snapshots().listen((snap) {
      if (_suppressListeners) return;
      _applyChanges<ProjectModel>(snap, _projectFromMap, (p) => p.id, _projectRepo.getAll().map((p) => p.id).toSet(), (p) => _projectRepo.add(p), (id) => _projectRepo.delete(id));
      _collectionChangeController.add(SyncCollection.projects);
    }, onError: (e) => debugPrint('[FirebaseSync] projects error: $e'));
  }

  StreamSubscription _listenTasks() {
    return _col('tasks').snapshots().listen((snap) {
      if (_suppressListeners) return;
      _applyChanges<TaskModel>(snap, _taskFromMap, (t) => t.id, _taskRepo.getAll().map((t) => t.id).toSet(), (t) => _taskRepo.add(t), (id) => _taskRepo.delete(id));
      _collectionChangeController.add(SyncCollection.tasks);
    }, onError: (e) => debugPrint('[FirebaseSync] tasks error: $e'));
  }

  StreamSubscription _listenTimeEntries() {
    return _col('time_entries').snapshots().listen((snap) {
      if (_suppressListeners) return;
      _applyChanges<TimeEntryModel>(
        snap,
        _timeEntryFromMap,
        (e) => e.id,
        _timeEntryRepo.getAll().map((e) => e.id).toSet(),
        (e) => _timeEntryRepo.add(e),
        (id) => _timeEntryRepo.delete(id),
      );
      _collectionChangeController.add(SyncCollection.timeEntries);
    }, onError: (e) => debugPrint('[FirebaseSync] time_entries error: $e'));
  }

  StreamSubscription _listenRunningTimers() {
    return _col('running_timers').snapshots().listen((snap) {
      if (_suppressListeners) return;
      _applyChanges<RunningTimerModel>(
        snap,
        _runningTimerFromMap,
        (t) => t.id,
        _runningTimerRepo.getAll().map((t) => t.id).toSet(),
        (t) => _runningTimerRepo.start(t),
        (id) => _runningTimerRepo.stop(id),
      );
      _collectionChangeController.add(SyncCollection.runningTimers);
    }, onError: (e) => debugPrint('[FirebaseSync] running_timers error: $e'));
  }

  StreamSubscription _listenMonthlyTargets() {
    return _col('monthly_targets').snapshots().listen((snap) {
      if (_suppressListeners) return;
      _applyChanges<MonthlyHoursTargetModel>(
        snap,
        _monthlyTargetFromMap,
        (m) => m.id,
        _monthlyTargetRepo.getAll().map((m) => m.id).toSet(),
        (m) => _monthlyTargetRepo.add(m),
        (id) => _monthlyTargetRepo.delete(id),
      );
      _collectionChangeController.add(SyncCollection.monthlyTargets);
    }, onError: (e) => debugPrint('[FirebaseSync] monthly_targets error: $e'));
  }

  /// Apply a Firestore snapshot to local Hive.
  void _applyChanges<T>(
    QuerySnapshot<Map<String, dynamic>> snap,
    T Function(Map<String, dynamic>) fromMap,
    String Function(T) getId,
    Set<String> localIds,
    Future<void> Function(T) upsert,
    Future<void> Function(String) delete,
  ) {
    for (final change in snap.docChanges) {
      final data = change.doc.data();
      if (data == null) continue;

      switch (change.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          final item = fromMap(data);
          upsert(item);
          break;
        case DocumentChangeType.removed:
          delete(change.doc.id);
          break;
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════════════════════════════════

  /// Replace remote collection with [items]. Deletes remote orphans.
  Future<void> _replaceRemote(String collection, Map<String, Map<String, dynamic>> items) async {
    // Use batched writes (Firestore max 500 per batch)
    final existing = await _col(collection).get();
    final existingIds = existing.docs.map((d) => d.id).toSet();

    var batch = _firestore.batch();
    var count = 0;

    // Upsert all local items
    for (final entry in items.entries) {
      batch.set(_doc(collection, entry.key), entry.value);
      count++;
      if (count >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }

    // Delete remote items not in local
    for (final rid in existingIds) {
      if (!items.containsKey(rid)) {
        batch.delete(_doc(collection, rid));
        count++;
        if (count >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }
    }

    if (count > 0) await batch.commit();
  }

  /// Download all documents from a Firestore collection.
  Future<List<T>> _downloadCollection<T>(String collection, T Function(Map<String, dynamic>) fromMap) async {
    final snap = await _col(collection).get();
    return snap.docs.map((doc) => fromMap(doc.data())).toList();
  }

  /// Replace local data with remote items.
  Future<void> _replaceLocal<T>(List<T> remoteItems, Set<String> localIds, Future<void> Function(T) upsert, Future<void> Function(String) delete, String Function(T) getId) async {
    final remoteIds = <String>{};
    for (final item in remoteItems) {
      remoteIds.add(getId(item));
      await upsert(item);
    }
    for (final lid in localIds) {
      if (!remoteIds.contains(lid)) {
        await delete(lid);
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Model ↔ Map serialization
  // ═════════════════════════════════════════════════════════════════════════

  // --- Category ---
  static Map<String, dynamic> _categoryToMap(CategoryModel c) => {'id': c.id, 'name': c.name, 'colorValue': c.colorValue, 'createdAt': Timestamp.fromDate(c.createdAt)};

  static CategoryModel _categoryFromMap(Map<String, dynamic> m) =>
      CategoryModel(id: m['id'] as String? ?? '', name: m['name'] as String? ?? '', colorValue: (m['colorValue'] as num?)?.toInt() ?? 0, createdAt: _tsToDate(m['createdAt']));

  // --- Project ---
  static Map<String, dynamic> _projectToMap(ProjectModel p) => {
    'id': p.id,
    'name': p.name,
    'categoryId': p.categoryId,
    'colorValue': p.colorValue,
    'hourlyRate': p.hourlyRate,
    'plannedTimeHours': p.plannedTimeHours,
    'plannedBudget': p.plannedBudget,
    'startDate': p.startDate != null ? Timestamp.fromDate(p.startDate!) : null,
    'dueDate': p.dueDate != null ? Timestamp.fromDate(p.dueDate!) : null,
    'notes': p.notes,
    'isArchived': p.isArchived,
    'isBillable': p.isBillable,
    'createdAt': Timestamp.fromDate(p.createdAt),
  };

  static ProjectModel _projectFromMap(Map<String, dynamic> m) => ProjectModel(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    categoryId: m['categoryId'] as String?,
    colorValue: (m['colorValue'] as num?)?.toInt() ?? 0,
    hourlyRate: (m['hourlyRate'] as num?)?.toDouble() ?? 0.0,
    plannedTimeHours: (m['plannedTimeHours'] as num?)?.toDouble() ?? 0.0,
    plannedBudget: (m['plannedBudget'] as num?)?.toDouble() ?? 0.0,
    startDate: _tsToDateOrNull(m['startDate']),
    dueDate: _tsToDateOrNull(m['dueDate']),
    notes: m['notes'] as String? ?? '',
    isArchived: m['isArchived'] as bool? ?? false,
    isBillable: m['isBillable'] as bool? ?? true,
    createdAt: _tsToDate(m['createdAt']),
  );

  // --- Task ---
  static Map<String, dynamic> _taskToMap(TaskModel t) => {
    'id': t.id,
    'projectId': t.projectId,
    'name': t.name,
    'hourlyRate': t.hourlyRate,
    'isBillable': t.isBillable,
    'notes': t.notes,
    'isArchived': t.isArchived,
    'createdAt': Timestamp.fromDate(t.createdAt),
    'colorValue': t.colorValue,
  };

  static TaskModel _taskFromMap(Map<String, dynamic> m) => TaskModel(
    id: m['id'] as String? ?? '',
    projectId: m['projectId'] as String? ?? '',
    name: m['name'] as String? ?? '',
    hourlyRate: (m['hourlyRate'] as num?)?.toDouble(),
    isBillable: m['isBillable'] as bool? ?? true,
    notes: m['notes'] as String? ?? '',
    isArchived: m['isArchived'] as bool? ?? false,
    createdAt: _tsToDate(m['createdAt']),
    colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFF6366F1,
  );

  // --- TimeEntry ---
  static Map<String, dynamic> _timeEntryToMap(TimeEntryModel e) => {
    'id': e.id,
    'projectId': e.projectId,
    'taskId': e.taskId,
    'startTime': Timestamp.fromDate(e.startTime),
    'endTime': e.endTime != null ? Timestamp.fromDate(e.endTime!) : null,
    'durationSeconds': e.durationSeconds,
    'notes': e.notes,
    'createdAt': Timestamp.fromDate(e.createdAt),
    'isBillable': e.isBillable,
  };

  static TimeEntryModel _timeEntryFromMap(Map<String, dynamic> m) => TimeEntryModel(
    id: m['id'] as String? ?? '',
    projectId: m['projectId'] as String? ?? '',
    taskId: m['taskId'] as String? ?? '',
    startTime: _tsToDate(m['startTime']),
    endTime: _tsToDateOrNull(m['endTime']),
    durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 0,
    notes: m['notes'] as String? ?? '',
    createdAt: _tsToDate(m['createdAt']),
    isBillable: m['isBillable'] as bool? ?? true,
  );

  // --- RunningTimer ---
  static Map<String, dynamic> _runningTimerToMap(RunningTimerModel t) => {
    'id': t.id,
    'projectId': t.projectId,
    'taskId': t.taskId,
    'startTime': Timestamp.fromDate(t.startTime),
    'notes': t.notes,
  };

  static RunningTimerModel _runningTimerFromMap(Map<String, dynamic> m) => RunningTimerModel(
    id: m['id'] as String? ?? '',
    projectId: m['projectId'] as String? ?? '',
    taskId: m['taskId'] as String? ?? '',
    startTime: _tsToDate(m['startTime']),
    notes: m['notes'] as String? ?? '',
  );

  // --- MonthlyHoursTarget ---
  static Map<String, dynamic> _monthlyTargetToMap(MonthlyHoursTargetModel t) => {
    'id': t.id,
    'name': t.name,
    'targetHours': t.targetHours,
    'projectIds': t.projectIds,
    'createdAt': Timestamp.fromDate(t.createdAt),
  };

  static MonthlyHoursTargetModel _monthlyTargetFromMap(Map<String, dynamic> m) => MonthlyHoursTargetModel(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    targetHours: (m['targetHours'] as num?)?.toDouble() ?? 0.0,
    projectIds: (m['projectIds'] as List<dynamic>?)?.cast<String>() ?? [],
    createdAt: _tsToDate(m['createdAt']),
  );

  // --- Timestamp helpers ---
  static DateTime _tsToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _tsToDateOrNull(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Dispose
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> dispose() async {
    await stopListeners();
    await _statusController.close();
    await _collectionChangeController.close();
  }
}
