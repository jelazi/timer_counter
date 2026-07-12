import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

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
import 'deletion_journal_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums & Result types
// ─────────────────────────────────────────────────────────────────────────────

enum SyncStatus { disabled, connecting, connected, error }

/// Event emitted when a remote change updates a local collection.
enum SyncCollection { categories, projects, tasks, timeEntries, runningTimers, monthlyTargets, dayOverrides }

/// Callback for reporting sync progress.
typedef SyncProgressCallback = void Function(String message, double progress);

/// Outcome of smart first sync analysis.
enum SmartSyncAction {
  /// Remote empty, local has data → uploaded local to cloud.
  uploaded,

  /// Local empty, remote has data → downloaded cloud to local.
  downloaded,

  /// Both empty → nothing to do.
  bothEmpty,

  /// Both have data → caller should ask user what to do.
  conflict,

  /// Already synced before → no action needed.
  alreadySynced,
}

/// Result of a sync operation.
class SyncResult {
  final int projectsSynced;
  final int tasksSynced;
  final int timeEntriesSynced;
  final int categoriesSynced;
  final int runningTimersSynced;
  final int monthlyTargetsSynced;
  final int dayOverridesSynced;
  final String? error;

  const SyncResult({
    this.projectsSynced = 0,
    this.tasksSynced = 0,
    this.timeEntriesSynced = 0,
    this.categoriesSynced = 0,
    this.runningTimersSynced = 0,
    this.monthlyTargetsSynced = 0,
    this.dayOverridesSynced = 0,
    this.error,
  });

  bool get hasError => error != null;
  int get total => projectsSynced + tasksSynced + timeEntriesSynced + categoriesSynced + runningTimersSynced + monthlyTargetsSynced + dayOverridesSynced;
}

/// A reconciliation that wanted to delete an implausible number of records and
/// was refused.
///
/// Sync reconciliation treats "absent on the other side" as "deleted". That is
/// indistinguishable from "the other side failed to report it", which is how a
/// network fault silently destroys data. When a reconcile wants to remove a
/// large fraction of a collection we assume the other side is wrong, keep the
/// records, and surface this report so the user can decide.
@immutable
class SyncGuardReport {
  /// Logical collection the deletions were blocked in.
  final String collection;

  /// Number of records the reconcile wanted to delete.
  final int blockedDeletions;

  /// Number of records the collection held locally at the time.
  final int localCount;

  /// Number of records the other side reported.
  final int remoteCount;

  /// True when the reconcile ran the other way (local → remote).
  final bool remoteSide;

  const SyncGuardReport({
    required this.collection,
    required this.blockedDeletions,
    required this.localCount,
    required this.remoteCount,
    this.remoteSide = false,
  });
}

/// Deletion thresholds above which a reconcile is treated as data loss, not intent.
class SyncGuard {
  SyncGuard._();

  /// Never auto-delete more than this fraction of a collection.
  static const double maxDeleteFraction = 0.3;

  /// Small collections need an absolute floor: deleting 2 of 3 projects is 66 %
  /// but perfectly normal. Below this count, fraction rules don't apply.
  static const int minDeletesBeforeGuard = 10;

  /// True when deleting [deleteCount] of [localCount] records is implausible
  /// enough that it more likely reflects a failed fetch than a real deletion.
  static bool blocks({required int deleteCount, required int localCount, required int remoteCount}) {
    if (deleteCount == 0) return false;

    // An empty other side while we hold data is never a legitimate reconcile —
    // it is what a failed or unauthorized fetch looks like.
    if (remoteCount == 0 && localCount > 0) return true;

    if (deleteCount < minDeletesBeforeGuard) return false;
    return deleteCount > localCount * maxDeleteFraction;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PocketBaseSyncService — PocketBase SDK with real-time subscriptions
// ─────────────────────────────────────────────────────────────────────────────

class PocketBaseSyncService {
  final CategoryRepository _categoryRepo;
  final ProjectRepository _projectRepo;
  final TaskRepository _taskRepo;
  final TimeEntryRepository _timeEntryRepo;
  final RunningTimerRepository _runningTimerRepo;
  final MonthlyHoursTargetRepository _monthlyTargetRepo;
  final SettingsRepository _settingsRepo;

  late PocketBase _pb;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  final _collectionChangeController = StreamController<SyncCollection>.broadcast();

  /// Emitted when a PocketBase subscription updates a local Hive collection.
  Stream<SyncCollection> get onCollectionChanged => _collectionChangeController.stream;

  final _authStateController = StreamController<bool>.broadcast();

  /// Emits `true` after a successful sign-in and `false` after sign-out.
  /// Used by the web `AuthGate` to switch between login screen and home.
  Stream<bool> get authStateStream => _authStateController.stream;

  final _accountSwitchController = StreamController<String>.broadcast();

  /// Emits the new user id when a different account signs in and the local store
  /// was wiped as a result. Blocs must reload — their in-memory state is stale.
  Stream<String> get onAccountSwitched => _accountSwitchController.stream;

  final _guardController = StreamController<SyncGuardReport>.broadcast();

  /// Emits whenever a reconcile was refused because it wanted to delete an
  /// implausible number of records. The UI warns the user instead of losing data.
  Stream<SyncGuardReport> get onGuardTriggered => _guardController.stream;

  DeletionJournalService? _journal;

  /// Attribute deletions performed by this service to the right source in the
  /// deletion journal.
  void attachJournal(DeletionJournalService journal) => _journal = journal;

  SyncStatus _currentStatus = SyncStatus.disabled;
  SyncStatus get currentStatus => _currentStatus;

  String? _lastError;
  String? get lastError => _lastError;

  bool _listenersActive = false;

  /// Suppresses local updates from PocketBase listeners during bulk operations.
  bool _suppressListeners = false;

  bool get isSignedIn => _pb.authStore.isValid;
  String? get userId => _pb.authStore.record?.id;
  String? get userEmail => _pb.authStore.record?.getStringValue('email');

  PocketBaseSyncService({
    required String serverUrl,
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
       _settingsRepo = settingsRepo {
    _pb = PocketBase(serverUrl);

    // Restore auth from settings
    final savedToken = _settingsRepo.getPocketBaseAuthToken();
    final savedModel = _settingsRepo.getPocketBaseAuthModel();
    if (savedToken.isNotEmpty && savedModel.isNotEmpty) {
      try {
        _pb.authStore.save(savedToken, RecordModel.fromJson(Map<String, dynamic>.from(_parseJsonString(savedModel))));
      } catch (e) {
        debugPrint('[PocketBaseSync] Failed to restore auth: $e');
        _settingsRepo.setPocketBaseAuthToken('');
        _settingsRepo.setPocketBaseAuthModel('');
      }
    }
  }

  /// Update server URL (e.g. from settings).
  void updateServerUrl(String url) {
    _pb = PocketBase(url);
    _lastError = null;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Authentication
  // ═════════════════════════════════════════════════════════════════════════

  /// Sign up with email/password. Returns null on success, error message on failure.
  Future<String?> signUp(String email, String password) async {
    try {
      await _pb.collection('users').create(body: {'email': email, 'password': password, 'passwordConfirm': password});
      // Auto sign-in after registration
      return await signIn(email, password);
    } on ClientException catch (e) {
      return e.response['message']?.toString() ?? e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with email/password. Returns null on success, error message on failure.
  Future<String?> signIn(String email, String password) async {
    try {
      _lastError = null;
      _setStatus(SyncStatus.connecting);
      await _pb.collection('users').authWithPassword(email, password);
      _saveAuthState();
      await _bindLocalStoreToAccount();
      _authStateController.add(true);
      return null;
    } on ClientException catch (e) {
      _lastError = e.response['message']?.toString() ?? e.toString();
      _setStatus(SyncStatus.error);
      return _lastError;
    } catch (e) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error);
      return _lastError;
    }
  }

  /// Sign out and stop all listeners.
  ///
  /// When [clearLocal] is true, all synced Hive boxes are wiped — important on
  /// shared browsers so the next user doesn't see leftover data.
  Future<void> signOut({bool clearLocal = false}) async {
    await stopListeners();
    _pb.authStore.clear();
    _settingsRepo.setPocketBaseAuthToken('');
    _settingsRepo.setPocketBaseAuthModel('');
    if (clearLocal) {
      await clearLocalData();
    }
    _lastError = null;
    _setStatus(SyncStatus.disabled);
    _authStateController.add(false);
  }

  /// Tie the local Hive store to the account that just signed in, wiping it
  /// first if it belongs to a different one.
  ///
  /// The local store is per-machine, but a PocketBase server can host many
  /// accounts. Without this, signing in as B on a machine that last synced as A
  /// leaves A's records sitting in Hive: B sees them in every screen, and the
  /// next `uploadAll()` re-creates them inside B's account (the client stamps
  /// `user: B` on every record it pushes). `smartFirstSync()` cannot catch this
  /// either — it short-circuits on the `lastSync` marker, which is global and
  /// still set from A's session.
  ///
  /// The wipe is journalled as a bulk clear, so if the switch was a mistake the
  /// previous account's records are still recoverable from the deletion journal.
  Future<void> _bindLocalStoreToAccount() async {
    final newOwner = userId;
    if (newOwner == null) return;

    final previousOwner = _settingsRepo.getPocketBaseOwnerId();
    if (previousOwner.isNotEmpty && previousOwner != newOwner) {
      debugPrint('[PocketBaseSync] Account switch ($previousOwner → $newOwner): clearing local store');
      await _journalled(DeleteSource.bulkClear, clearLocalData);

      // Blocs still hold the previous account's records in memory.
      for (final c in SyncCollection.values) {
        _collectionChangeController.add(c);
      }
      _accountSwitchController.add(newOwner);
    }

    // Also covers the first-ever sign-in, where there is nothing to wipe.
    await _settingsRepo.setPocketBaseOwnerId(newOwner);
  }

  /// Wipe all synced Hive collections and the `lastSync` marker.
  /// Does NOT touch user preferences (theme, language, work schedule, etc.).
  Future<void> clearLocalData() async {
    await _categoryRepo.deleteAll();
    await _projectRepo.deleteAll();
    await _taskRepo.deleteAll();
    await _timeEntryRepo.deleteAll();
    await _runningTimerRepo.stopAll();
    await _monthlyTargetRepo.deleteAll();
    await _settingsRepo.restoreAllDayOverrides({});
    await _settingsRepo.setPocketBaseLastSync('');
  }

  void _saveAuthState() {
    _settingsRepo.setPocketBaseAuthToken(_pb.authStore.token);
    final record = _pb.authStore.record;
    if (record != null) {
      _settingsRepo.setPocketBaseAuthModel(_toJsonString(record.toJson()));
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Listener management — real-time sync via SSE subscriptions
  // ═════════════════════════════════════════════════════════════════════════

  /// Start real-time PocketBase subscriptions for all collections.
  /// Must be signed in first.
  Future<void> startListeners() async {
    if (!isSignedIn || _listenersActive) return;
    _listenersActive = true;
    _setStatus(SyncStatus.connecting);

    try {
      await _subscribeCategories();
      await _subscribeProjects();
      await _subscribeTasks();
      await _subscribeTimeEntries();
      await _subscribeRunningTimers();
      await _subscribeMonthlyTargets();
      await _subscribeDayOverrides();

      _setStatus(SyncStatus.connected);
      _lastError = null;
      debugPrint('[PocketBaseSync] Real-time subscriptions started for user $userId');
    } catch (e) {
      debugPrint('[PocketBaseSync] Failed to start listeners: $e');
      _lastError = e.toString();
      _setStatus(SyncStatus.error);
    }
  }

  /// Stop all PocketBase subscriptions.
  Future<void> stopListeners() async {
    try {
      await _pb.collection('categories').unsubscribe();
      await _pb.collection('projects').unsubscribe();
      await _pb.collection('tasks').unsubscribe();
      await _pb.collection('time_entries').unsubscribe();
      await _pb.collection('running_timers').unsubscribe();
      await _pb.collection('monthly_targets').unsubscribe();
      await _pb.collection('day_overrides').unsubscribe();
    } catch (e) {
      debugPrint('[PocketBaseSync] Error stopping listeners: $e');
    }
    _listenersActive = false;
    debugPrint('[PocketBaseSync] Listeners stopped');
  }

  void _setStatus(SyncStatus s) {
    _currentStatus = s;
    _statusController.add(s);
  }

  /// Reconnect real-time subscriptions and pull any changes missed while
  /// disconnected.
  ///
  /// Mobile platforms suspend the SSE connection when the app is backgrounded,
  /// and PocketBase does not replay events that happened while disconnected. So
  /// on resume we must re-subscribe AND explicitly pull the current remote
  /// state, then notify listening blocs to reload from the local store.
  Future<void> resync() async {
    if (!isSignedIn) return;
    debugPrint('[PocketBaseSync] Resync triggered');

    // Re-establish subscriptions — the previous connection may be dead.
    await stopListeners();
    await startListeners();

    // SSE does not replay missed events, so pull the current remote state.
    final result = await downloadAll();
    if (result.hasError) {
      debugPrint('[PocketBaseSync] Resync download error: ${result.error}');
      return;
    }

    // Notify blocs so they reload from the freshly updated local store.
    for (final c in SyncCollection.values) {
      _collectionChangeController.add(c);
    }
    debugPrint('[PocketBaseSync] Resync complete: ${result.total} items');
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PUSH — write single record to PocketBase
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> pushCategory(CategoryModel c) async {
    if (!isSignedIn) return;
    await _upsertRecord('categories', c.id, _categoryToMap(c));
  }

  Future<void> deleteCategory(String id) async {
    if (!isSignedIn) return;
    await _deleteRecord('categories', id);
  }

  Future<void> pushProject(ProjectModel p) async {
    if (!isSignedIn) return;
    await _upsertRecord('projects', p.id, _projectToMap(p));
  }

  Future<void> deleteProject(String id) async {
    if (!isSignedIn) return;
    await _deleteRecord('projects', id);
  }

  Future<void> pushTask(TaskModel t) async {
    if (!isSignedIn) return;
    await _upsertRecord('tasks', t.id, _taskToMap(t));
  }

  Future<void> deleteTask(String id) async {
    if (!isSignedIn) return;
    await _deleteRecord('tasks', id);
  }

  Future<void> pushTimeEntry(TimeEntryModel e) async {
    if (!isSignedIn) return;
    await _upsertRecord('time_entries', e.id, _timeEntryToMap(e));
  }

  Future<void> deleteTimeEntry(String id) async {
    if (!isSignedIn) return;
    await _deleteRecord('time_entries', id);
  }

  Future<void> pushRunningTimer(RunningTimerModel t) async {
    if (!isSignedIn) return;
    await _upsertRecord('running_timers', t.id, _runningTimerToMap(t));
  }

  Future<void> deleteRunningTimer(String id) async {
    if (!isSignedIn) return;
    await _deleteRecord('running_timers', id);
  }

  Future<void> pushMonthlyTarget(MonthlyHoursTargetModel m) async {
    if (!isSignedIn) return;
    await _upsertRecord('monthly_targets', m.id, _monthlyTargetToMap(m));
  }

  Future<void> deleteMonthlyTarget(String id) async {
    if (!isSignedIn) return;
    await _deleteRecord('monthly_targets', id);
  }

  Future<void> pushDayOverride(DateTime date, String type) async {
    if (!isSignedIn) return;
    final dateKey = _dateKey(date);
    await _upsertRecord('day_overrides', dateKey, {'item_id': dateKey, 'date': dateKey, 'override_type': type});
  }

  Future<void> deleteDayOverride(DateTime date) async {
    if (!isSignedIn) return;
    await _deleteRecord('day_overrides', _dateKey(date));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BULK — initial upload / download
  // ═════════════════════════════════════════════════════════════════════════

  /// Upload all local data to PocketBase, replacing remote.
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

      onProgress?.call('Day overrides…', 0.96);
      final dayOverrides = _settingsRepo.getAllDayOverrides();
      await _replaceRemote('day_overrides', {
        for (final entry in dayOverrides.entries) entry.key: {'item_id': entry.key, 'date': entry.key, 'override_type': entry.value},
      });

      _settingsRepo.setPocketBaseLastSync(DateTime.now().toIso8601String());
      onProgress?.call('Done', 1.0);
      return SyncResult(
        categoriesSynced: categories.length,
        projectsSynced: projects.length,
        tasksSynced: tasks.length,
        timeEntriesSynced: entries.length,
        runningTimersSynced: timers.length,
        monthlyTargetsSynced: targets.length,
        dayOverridesSynced: dayOverrides.length,
      );
    } catch (e) {
      return SyncResult(error: e.toString());
    } finally {
      _suppressListeners = false;
    }
  }

  /// Download all remote data, replacing local.
  ///
  /// Runs in two strictly separated phases. Phase 1 fetches every collection
  /// into memory; if any fetch fails or comes back incomplete, we return an
  /// error **without having touched Hive**. Only once all data is in hand does
  /// phase 2 write it.
  ///
  /// This ordering is the fix for a data-loss bug: reconciliation deletes local
  /// records missing from the remote list, so applying collections as they
  /// streamed in meant a network fault midway left the already-applied
  /// collections reconciled against a truncated download — silently destroying
  /// records that a later `uploadAll()` then deleted server-side too.
  Future<SyncResult> downloadAll({SyncProgressCallback? onProgress}) async {
    if (!isSignedIn) return const SyncResult(error: 'Not signed in');
    _suppressListeners = true;
    try {
      // ── Phase 1: fetch everything. No writes. ────────────────────────────
      onProgress?.call('Categories…', 0.05);
      final cats = await _downloadCollection('categories', _categoryFromMap);

      onProgress?.call('Projects…', 0.15);
      final projs = await _downloadCollection('projects', _projectFromMap);

      onProgress?.call('Tasks…', 0.30);
      final tasks = await _downloadCollection('tasks', _taskFromMap);

      onProgress?.call('Time entries…', 0.50);
      final entries = await _downloadCollection('time_entries', _timeEntryFromMap);

      onProgress?.call('Running timers…', 0.70);
      final timers = await _downloadCollection('running_timers', _runningTimerFromMap);

      onProgress?.call('Monthly targets…', 0.80);
      final targets = await _downloadCollection('monthly_targets', _monthlyTargetFromMap);

      onProgress?.call('Day overrides…', 0.85);
      final remoteDayOverrides = await _downloadCollection<MapEntry<String, String>>('day_overrides', _dayOverrideFromMap);

      // ── Phase 2: apply. Everything is in hand, so a failure here cannot
      // leave us reconciled against a partial download. ─────────────────────
      onProgress?.call('Applying…', 0.90);
      await _journalled(DeleteSource.syncReconcile, () async {
        await _replaceLocal<CategoryModel>(
          'categories',
          cats,
          _categoryRepo.getAll().map((c) => c.id).toSet(),
          (c) => _categoryRepo.add(c),
          (id) => _categoryRepo.delete(id),
          (c) => c.id,
        );
        await _replaceLocal<ProjectModel>(
          'projects',
          projs,
          _projectRepo.getAll().map((p) => p.id).toSet(),
          (p) => _projectRepo.add(p),
          (id) => _projectRepo.delete(id),
          (p) => p.id,
        );
        await _replaceLocal<TaskModel>('tasks', tasks, _taskRepo.getAll().map((t) => t.id).toSet(), (t) => _taskRepo.add(t), (id) => _taskRepo.delete(id), (t) => t.id);
        await _replaceLocal<TimeEntryModel>(
          'time_entries',
          entries,
          _timeEntryRepo.getAll().map((e) => e.id).toSet(),
          (e) => _timeEntryRepo.add(e),
          (id) => _timeEntryRepo.delete(id),
          (e) => e.id,
        );
        await _replaceLocal<RunningTimerModel>(
          'running_timers',
          timers,
          _runningTimerRepo.getAll().map((t) => t.id).toSet(),
          (t) => _runningTimerRepo.start(t),
          (id) => _runningTimerRepo.stop(id),
          (t) => t.id,
        );
        await _replaceLocal<MonthlyHoursTargetModel>(
          'monthly_targets',
          targets,
          _monthlyTargetRepo.getAll().map((m) => m.id).toSet(),
          (m) => _monthlyTargetRepo.add(m),
          (id) => _monthlyTargetRepo.delete(id),
          (m) => m.id,
        );
      });

      // Day overrides are cheap settings keys, not records — but the same
      // "empty remote must not wipe local" rule applies.
      final localOverrides = _settingsRepo.getAllDayOverrides();
      if (remoteDayOverrides.isEmpty && localOverrides.isNotEmpty) {
        _reportGuard(SyncGuardReport(collection: 'day_overrides', blockedDeletions: localOverrides.length, localCount: localOverrides.length, remoteCount: 0));
      } else {
        await _settingsRepo.restoreAllDayOverrides({for (final entry in remoteDayOverrides) entry.key: entry.value});
      }

      _settingsRepo.setPocketBaseLastSync(DateTime.now().toIso8601String());
      onProgress?.call('Done', 1.0);
      return SyncResult(
        categoriesSynced: cats.length,
        projectsSynced: projs.length,
        tasksSynced: tasks.length,
        timeEntriesSynced: entries.length,
        runningTimersSynced: timers.length,
        monthlyTargetsSynced: targets.length,
        dayOverridesSynced: remoteDayOverrides.length,
      );
    } catch (e) {
      debugPrint('[PocketBaseSync] downloadAll aborted, local data untouched: $e');
      return SyncResult(error: e.toString());
    } finally {
      _suppressListeners = false;
    }
  }

  /// Attribute every deletion made inside [body] to [source] in the journal.
  Future<void> _journalled(DeleteSource source, Future<void> Function() body) async {
    final journal = _journal;
    if (journal == null) return body();
    return journal.withSource(source, body);
  }

  void _reportGuard(SyncGuardReport report) {
    debugPrint(
      '[PocketBaseSync] GUARD: refused to delete ${report.blockedDeletions} of ${report.localCount} '
      '${report.collection} (remote reported ${report.remoteCount})',
    );
    _guardController.add(report);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SMART FIRST SYNC — detect initial state and act accordingly
  // ═════════════════════════════════════════════════════════════════════════

  /// Count total remote records across all synced collections for this user.
  Future<int> countRemoteRecords() async {
    if (!isSignedIn) return 0;
    int total = 0;
    for (final coll in ['categories', 'projects', 'tasks', 'time_entries', 'running_timers', 'monthly_targets', 'day_overrides']) {
      try {
        final result = await _pb.collection(coll).getList(filter: 'user = "$userId"', perPage: 1);
        total += result.totalItems;
      } catch (e) {
        debugPrint('[PocketBaseSync] countRemote $coll error: $e');
      }
    }
    return total;
  }

  /// Count total local records across all synced collections.
  int countLocalRecords() {
    return _categoryRepo.getAll().length +
        _projectRepo.getAll().length +
        _taskRepo.getAll().length +
        _timeEntryRepo.getAll().length +
        _runningTimerRepo.getAll().length +
        _monthlyTargetRepo.getAll().length +
        _settingsRepo.getAllDayOverrides().length;
  }

  /// Perform smart first sync after initial connection.
  ///
  /// - If already synced before (`lastSync` not empty) → [SmartSyncAction.alreadySynced]
  /// - Remote empty + local has data → auto upload → [SmartSyncAction.uploaded]
  /// - Local empty + remote has data → auto download → [SmartSyncAction.downloaded]
  /// - Both empty → [SmartSyncAction.bothEmpty]
  /// - Both have data → [SmartSyncAction.conflict] (caller decides)
  Future<(SmartSyncAction, SyncResult?)> smartFirstSync({SyncProgressCallback? onProgress}) async {
    if (!isSignedIn) return (SmartSyncAction.alreadySynced, null);

    final lastSync = _settingsRepo.getPocketBaseLastSync();
    if (lastSync.isNotEmpty) {
      debugPrint('[PocketBaseSync] Already synced before ($lastSync), skipping smart first sync');
      return (SmartSyncAction.alreadySynced, null);
    }

    debugPrint('[PocketBaseSync] First connection detected, running smart first sync…');
    onProgress?.call('Checking remote data…', 0.1);

    final remoteCount = await countRemoteRecords();
    final localCount = countLocalRecords();

    debugPrint('[PocketBaseSync] Local: $localCount records, Remote: $remoteCount records');

    if (remoteCount == 0 && localCount == 0) {
      // Both empty — nothing to sync
      _settingsRepo.setPocketBaseLastSync(DateTime.now().toIso8601String());
      return (SmartSyncAction.bothEmpty, const SyncResult());
    }

    if (remoteCount == 0 && localCount > 0) {
      // Remote empty → upload local data
      onProgress?.call('Uploading local data to cloud…', 0.2);
      final result = await uploadAll(onProgress: onProgress);
      return (SmartSyncAction.uploaded, result);
    }

    if (localCount == 0 && remoteCount > 0) {
      // Local empty → download remote data
      onProgress?.call('Downloading cloud data…', 0.2);
      final result = await downloadAll(onProgress: onProgress);
      return (SmartSyncAction.downloaded, result);
    }

    // Both have data → conflict, let caller decide
    return (SmartSyncAction.conflict, null);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Real-time subscriptions — PocketBase → Hive
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _subscribeCategories() async {
    await _pb.collection('categories').subscribe('*', (e) {
      if (_suppressListeners) return;
      _handleEvent<CategoryModel>(e, _categoryFromMap, (c) => _categoryRepo.add(c), (id) => _categoryRepo.delete(id));
      _collectionChangeController.add(SyncCollection.categories);
    }, filter: 'user = "$userId"');
  }

  Future<void> _subscribeProjects() async {
    await _pb.collection('projects').subscribe('*', (e) {
      if (_suppressListeners) return;
      _handleEvent<ProjectModel>(e, _projectFromMap, (p) => _projectRepo.add(p), (id) => _projectRepo.delete(id));
      _collectionChangeController.add(SyncCollection.projects);
    }, filter: 'user = "$userId"');
  }

  Future<void> _subscribeTasks() async {
    await _pb.collection('tasks').subscribe('*', (e) {
      if (_suppressListeners) return;
      _handleEvent<TaskModel>(e, _taskFromMap, (t) => _taskRepo.add(t), (id) => _taskRepo.delete(id));
      _collectionChangeController.add(SyncCollection.tasks);
    }, filter: 'user = "$userId"');
  }

  Future<void> _subscribeTimeEntries() async {
    await _pb.collection('time_entries').subscribe('*', (e) {
      if (_suppressListeners) return;
      _handleEvent<TimeEntryModel>(e, _timeEntryFromMap, (entry) => _timeEntryRepo.add(entry), (id) => _timeEntryRepo.delete(id));
      _collectionChangeController.add(SyncCollection.timeEntries);
    }, filter: 'user = "$userId"');
  }

  Future<void> _subscribeRunningTimers() async {
    await _pb.collection('running_timers').subscribe('*', (e) {
      if (_suppressListeners) return;
      _handleEvent<RunningTimerModel>(e, _runningTimerFromMap, (t) => _runningTimerRepo.start(t), (id) => _runningTimerRepo.stop(id));
      _collectionChangeController.add(SyncCollection.runningTimers);
    }, filter: 'user = "$userId"');
  }

  Future<void> _subscribeMonthlyTargets() async {
    await _pb.collection('monthly_targets').subscribe('*', (e) {
      if (_suppressListeners) return;
      _handleEvent<MonthlyHoursTargetModel>(e, _monthlyTargetFromMap, (m) => _monthlyTargetRepo.add(m), (id) => _monthlyTargetRepo.delete(id));
      _collectionChangeController.add(SyncCollection.monthlyTargets);
    }, filter: 'user = "$userId"');
  }

  Future<void> _subscribeDayOverrides() async {
    await _pb.collection('day_overrides').subscribe('*', (e) async {
      if (_suppressListeners) return;
      final record = e.record;
      if (record == null) return;

      final itemId = record.getStringValue('item_id');
      final date = _parseDateKeyOrNull(itemId);
      if (date == null) return;

      switch (e.action) {
        case 'create':
        case 'update':
          final type = record.getStringValue('override_type');
          if (type == 'off' || type == 'work') {
            await _settingsRepo.setDayOverride(date, type);
            _collectionChangeController.add(SyncCollection.dayOverrides);
          }
          break;
        case 'delete':
          await _settingsRepo.setDayOverride(date, null);
          _collectionChangeController.add(SyncCollection.dayOverrides);
          break;
      }
    }, filter: 'user = "$userId"');
  }

  void _handleEvent<T>(RecordSubscriptionEvent event, T Function(Map<String, dynamic>) fromMap, Future<void> Function(T) upsert, Future<void> Function(String) delete) {
    final record = event.record;
    if (record == null) return;

    switch (event.action) {
      case 'create':
      case 'update':
        final item = fromMap(record.toJson());
        upsert(item);
        break;
      case 'delete':
        final itemId = record.getStringValue('item_id');
        if (itemId.isNotEmpty) {
          _journalled(DeleteSource.syncRealtime, () => delete(itemId));
        }
        break;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════════════════════════════════

  /// Upsert a record — try update first, create if not found.
  Future<void> _upsertRecord(String collection, String itemId, Map<String, dynamic> data) async {
    try {
      // Search for existing record by item_id
      final existing = await _pb.collection(collection).getList(filter: 'item_id = "$itemId" && user = "$userId"', perPage: 1);
      if (existing.items.isNotEmpty) {
        await _pb.collection(collection).update(existing.items.first.id, body: data);
      } else {
        await _pb.collection(collection).create(body: {...data, 'user': userId});
      }
    } catch (e) {
      debugPrint('[PocketBaseSync] upsert $collection/$itemId error: $e');
    }
  }

  /// Delete a record by item_id.
  Future<void> _deleteRecord(String collection, String itemId) async {
    try {
      final existing = await _pb.collection(collection).getList(filter: 'item_id = "$itemId" && user = "$userId"', perPage: 1);
      if (existing.items.isNotEmpty) {
        await _pb.collection(collection).delete(existing.items.first.id);
      }
    } catch (e) {
      debugPrint('[PocketBaseSync] delete $collection/$itemId error: $e');
    }
  }

  /// Replace remote collection with [items]. Deletes remote orphans.
  Future<void> _replaceRemote(String collection, Map<String, Map<String, dynamic>> items) async {
    // Get all existing remote records for this user
    final existingRecords = <String, String>{}; // item_id -> pb record id
    int page = 1;
    while (true) {
      final result = await _pb.collection(collection).getList(filter: 'user = "$userId"', perPage: 200, page: page);
      for (final record in result.items) {
        existingRecords[record.getStringValue('item_id')] = record.id;
      }
      if (result.items.length < 200) break;
      page++;
    }

    final remoteCountBefore = existingRecords.length;

    // Upsert all local items
    for (final entry in items.entries) {
      final pbId = existingRecords[entry.key];
      if (pbId != null) {
        await _pb.collection(collection).update(pbId, body: entry.value);
        existingRecords.remove(entry.key);
      } else {
        await _pb.collection(collection).create(body: {...entry.value, 'user': userId});
      }
    }

    // Delete remote orphans — but only if this looks like a real deletion and
    // not a truncated/empty local store about to wipe a healthy server.
    final orphans = existingRecords.values.toList();
    if (SyncGuard.blocks(deleteCount: orphans.length, localCount: remoteCountBefore, remoteCount: items.length)) {
      _reportGuard(
        SyncGuardReport(collection: collection, blockedDeletions: orphans.length, localCount: items.length, remoteCount: remoteCountBefore, remoteSide: true),
      );
      return;
    }

    for (final pbId in orphans) {
      await _pb.collection(collection).delete(pbId);
    }
  }

  /// Download all records from a PocketBase collection for the current user.
  ///
  /// Verifies the collected count against the server's `totalItems`. A short
  /// read must never be mistaken for "the server has fewer records" — that is
  /// exactly what causes reconciliation to delete local data.
  Future<List<T>> _downloadCollection<T>(String collection, T Function(Map<String, dynamic>) fromMap) async {
    final results = <T>[];
    int page = 1;
    int expectedTotal = -1;
    while (true) {
      final result = await _pb.collection(collection).getList(filter: 'user = "$userId"', perPage: 200, page: page);
      if (expectedTotal < 0) expectedTotal = result.totalItems;
      for (final record in result.items) {
        results.add(fromMap(record.toJson()));
      }
      if (result.items.length < 200) break;
      page++;
    }

    if (expectedTotal >= 0 && results.length != expectedTotal) {
      throw StateError('Incomplete download of "$collection": got ${results.length} records, server reported $expectedTotal');
    }
    return results;
  }

  /// Reconcile a local collection against the freshly downloaded remote list.
  ///
  /// Upserts are always safe. Deletions are not: a record missing from
  /// [remoteItems] means "deleted remotely" *or* "the server failed to tell us
  /// about it", and we cannot distinguish the two. So a suspiciously large
  /// deletion batch is refused and reported rather than applied — see [SyncGuard].
  Future<void> _replaceLocal<T>(
    String collection,
    List<T> remoteItems,
    Set<String> localIds,
    Future<void> Function(T) upsert,
    Future<void> Function(String) delete,
    String Function(T) getId,
  ) async {
    final remoteIds = <String>{};
    for (final item in remoteItems) {
      remoteIds.add(getId(item));
      await upsert(item);
    }

    final toDelete = localIds.where((id) => !remoteIds.contains(id)).toList();
    if (SyncGuard.blocks(deleteCount: toDelete.length, localCount: localIds.length, remoteCount: remoteItems.length)) {
      _reportGuard(
        SyncGuardReport(collection: collection, blockedDeletions: toDelete.length, localCount: localIds.length, remoteCount: remoteItems.length),
      );
      return;
    }

    for (final id in toDelete) {
      await delete(id);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Model ↔ Map serialization
  // ═════════════════════════════════════════════════════════════════════════

  // --- Category ---
  Map<String, dynamic> _categoryToMap(CategoryModel c) => {'item_id': c.id, 'name': c.name, 'color_value': c.colorValue, 'created_at': c.createdAt.toIso8601String()};

  CategoryModel _categoryFromMap(Map<String, dynamic> m) => CategoryModel(
    id: m['item_id'] as String? ?? m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    colorValue: (m['color_value'] as num?)?.toInt() ?? 0,
    createdAt: _parseDate(m['created_at']),
  );

  // --- Project ---
  Map<String, dynamic> _projectToMap(ProjectModel p) => {
    'item_id': p.id,
    'name': p.name,
    'category_id': p.categoryId ?? '',
    'color_value': p.colorValue,
    'hourly_rate': p.hourlyRate,
    'planned_time_hours': p.plannedTimeHours,
    'planned_budget': p.plannedBudget,
    'start_date': p.startDate?.toIso8601String() ?? '',
    'due_date': p.dueDate?.toIso8601String() ?? '',
    'notes': p.notes,
    'is_archived': p.isArchived,
    'is_billable': p.isBillable,
    'created_at': p.createdAt.toIso8601String(),
  };

  ProjectModel _projectFromMap(Map<String, dynamic> m) => ProjectModel(
    id: m['item_id'] as String? ?? m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    categoryId: _emptyToNull(m['category_id']),
    colorValue: (m['color_value'] as num?)?.toInt() ?? 0,
    hourlyRate: (m['hourly_rate'] as num?)?.toDouble() ?? 0.0,
    plannedTimeHours: (m['planned_time_hours'] as num?)?.toDouble() ?? 0.0,
    plannedBudget: (m['planned_budget'] as num?)?.toDouble() ?? 0.0,
    startDate: _parseDateOrNull(m['start_date']),
    dueDate: _parseDateOrNull(m['due_date']),
    notes: m['notes'] as String? ?? '',
    isArchived: m['is_archived'] as bool? ?? false,
    isBillable: m['is_billable'] as bool? ?? true,
    createdAt: _parseDate(m['created_at']),
  );

  // --- Task ---
  Map<String, dynamic> _taskToMap(TaskModel t) => {
    'item_id': t.id,
    'project_id': t.projectId,
    'name': t.name,
    'hourly_rate': t.hourlyRate ?? 0.0,
    'is_billable': t.isBillable,
    'notes': t.notes,
    'is_archived': t.isArchived,
    'created_at': t.createdAt.toIso8601String(),
    'color_value': t.colorValue,
  };

  TaskModel _taskFromMap(Map<String, dynamic> m) => TaskModel(
    id: m['item_id'] as String? ?? m['id'] as String? ?? '',
    projectId: m['project_id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    hourlyRate: (m['hourly_rate'] as num?)?.toDouble(),
    isBillable: m['is_billable'] as bool? ?? true,
    notes: m['notes'] as String? ?? '',
    isArchived: m['is_archived'] as bool? ?? false,
    createdAt: _parseDate(m['created_at']),
    colorValue: (m['color_value'] as num?)?.toInt() ?? 0xFF6366F1,
  );

  // --- TimeEntry ---
  Map<String, dynamic> _timeEntryToMap(TimeEntryModel e) => {
    'item_id': e.id,
    'project_id': e.projectId,
    'task_id': e.taskId,
    'start_time': e.startTime.toIso8601String(),
    'end_time': e.endTime?.toIso8601String() ?? '',
    'duration_seconds': e.durationSeconds,
    'notes': e.notes,
    'created_at': e.createdAt.toIso8601String(),
    'is_billable': e.isBillable,
  };

  TimeEntryModel _timeEntryFromMap(Map<String, dynamic> m) => TimeEntryModel(
    id: m['item_id'] as String? ?? m['id'] as String? ?? '',
    projectId: m['project_id'] as String? ?? '',
    taskId: m['task_id'] as String? ?? '',
    startTime: _parseDate(m['start_time']),
    endTime: _parseDateOrNull(m['end_time']),
    durationSeconds: (m['duration_seconds'] as num?)?.toInt() ?? 0,
    notes: m['notes'] as String? ?? '',
    createdAt: _parseDate(m['created_at']),
    isBillable: m['is_billable'] as bool? ?? true,
  );

  // --- RunningTimer ---
  Map<String, dynamic> _runningTimerToMap(RunningTimerModel t) => {
    'item_id': t.id,
    'project_id': t.projectId,
    'task_id': t.taskId,
    'start_time': t.startTime.toIso8601String(),
    'notes': t.notes,
  };

  RunningTimerModel _runningTimerFromMap(Map<String, dynamic> m) => RunningTimerModel(
    id: m['item_id'] as String? ?? m['id'] as String? ?? '',
    projectId: m['project_id'] as String? ?? '',
    taskId: m['task_id'] as String? ?? '',
    startTime: _parseDate(m['start_time']),
    notes: m['notes'] as String? ?? '',
  );

  // --- MonthlyHoursTarget ---
  Map<String, dynamic> _monthlyTargetToMap(MonthlyHoursTargetModel t) => {
    'item_id': t.id,
    'name': t.name,
    'target_hours': t.targetHours,
    'project_ids': t.projectIds.join(','),
    'created_at': t.createdAt.toIso8601String(),
  };

  MonthlyHoursTargetModel _monthlyTargetFromMap(Map<String, dynamic> m) => MonthlyHoursTargetModel(
    id: m['item_id'] as String? ?? m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    targetHours: (m['target_hours'] as num?)?.toDouble() ?? 0.0,
    projectIds: _parseProjectIds(m['project_ids']),
    createdAt: _parseDate(m['created_at']),
  );

  MapEntry<String, String> _dayOverrideFromMap(Map<String, dynamic> m) {
    final date = m['date'] as String? ?? m['item_id'] as String? ?? '';
    final type = m['override_type'] as String? ?? '';
    return MapEntry(date, type);
  }

  // --- Date helpers ---
  static DateTime _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static DateTime? _parseDateOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _emptyToNull(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isEmpty) return null;
    return value.toString();
  }

  static List<String> _parseProjectIds(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<String>();
    if (value is String && value.isNotEmpty) return value.split(',');
    return [];
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDateKeyOrNull(String value) {
    if (value.isEmpty) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  // Simple JSON string helpers
  static String _toJsonString(Map<String, dynamic> map) {
    return jsonEncode(map);
  }

  static Map<String, dynamic> _parseJsonString(String json) {
    try {
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (_) {
      return {};
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Dispose
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> dispose() async {
    await stopListeners();
    await _statusController.close();
    await _collectionChangeController.close();
    await _authStateController.close();
    await _guardController.close();
    await _accountSwitchController.close();
  }
}
