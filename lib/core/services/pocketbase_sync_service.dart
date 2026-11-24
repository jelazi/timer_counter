import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/category_model.dart';
import '../../data/models/client_model.dart';
import '../../data/models/monthly_hours_target_model.dart';
import '../../data/models/pomodoro_session.dart';
import '../../data/models/pomodoro_settings.dart';
import '../../data/models/project_client_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/running_timer_model.dart';
import '../../data/models/standalone_invoice_model.dart';
import '../../data/models/supplier_profile.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/monthly_hours_target_repository.dart';
import '../../data/repositories/pomodoro_repository.dart';
import '../../data/repositories/project_client_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/running_timer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/standalone_invoice_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import 'deletion_journal_service.dart';
import 'pomodoro_engine.dart';
import 'pomodoro_state_merge.dart';
import 'sync_ledger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums & Result types
// ─────────────────────────────────────────────────────────────────────────────

enum SyncStatus { disabled, connecting, connected, error }

/// Event emitted when a remote change updates a local collection.
enum SyncCollection {
  categories,
  projects,
  tasks,
  timeEntries,
  runningTimers,
  monthlyTargets,
  dayOverrides,
  contextSettings,
  contextDayOverrides,
  clients,
  projectClients,
  invoices,
  supplierProfile,
  pomodoroState,
  pomodoroSettings,
  pomodoroSessions,
}

/// Collections added for per-context work schedules.
///
/// A server whose schema predates them simply does not have them, and an older
/// app version never reads or writes them. Both cases must degrade to "no
/// context data" rather than failing the sync, so every access to these is
/// tolerant of a missing collection.
const _contextSettingsCollection = 'context_settings';
const _contextDayOverridesCollection = 'context_day_overrides';

/// Collections added for clients and synced invoices. Same rule as the context
/// collections: optional on the server, and a server without them leaves the
/// rest of the sync untouched while local changes wait in the ledger.
const _clientsCollection = 'clients';
const _projectClientsCollection = 'project_clients';
const _invoicesCollection = 'invoices';
const _userSettingsCollection = 'user_settings';

/// Item id of the supplier profile record in [_userSettingsCollection].
const _supplierProfileItem = 'supplier_profile';

/// Item id of the pomodoro settings record in [_userSettingsCollection].
const _pomodoroSettingsItem = 'pomodoro_settings';

/// Optional like the client collections. Holds one record per account that is
/// never deleted: an ended session is a record without a session.
const _pomodoroStateCollection = 'pomodoro_state';
const _pomodoroStateItem = 'current';

/// Finished pomodoro sessions. Records never change, they are only added or
/// deleted, and a full upload never deletes server records the device lacks.
const _pomodoroSessionsCollection = 'pomodoro_sessions';

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

  const SyncGuardReport({required this.collection, required this.blockedDeletions, required this.localCount, required this.remoteCount, this.remoteSide = false});
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
  final ClientRepository _clientRepo;
  final ProjectClientRepository _projectClientRepo;
  final StandaloneInvoiceRepository _invoiceRepo;
  final PomodoroRepository? _pomodoroRepo;
  final http.Client Function()? _httpClientFactory;

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

  late final SyncLedger _ledger;

  /// Kept in memory only, so an expired token can be replaced without the user.
  String? _email;
  String? _password;

  Future<bool>? _authInFlight;
  Timer? _keepAliveTimer;
  bool _flushing = false;

  static const Duration _keepAliveInterval = Duration(minutes: 30);
  static const Duration _tokenRefreshMargin = Duration(days: 1);

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
    required ClientRepository clientRepo,
    required ProjectClientRepository projectClientRepo,
    required StandaloneInvoiceRepository invoiceRepo,
    PomodoroRepository? pomodoroRepo,
    @visibleForTesting http.Client Function()? httpClientFactory,
  }) : _categoryRepo = categoryRepo,
       _projectRepo = projectRepo,
       _taskRepo = taskRepo,
       _timeEntryRepo = timeEntryRepo,
       _runningTimerRepo = runningTimerRepo,
       _monthlyTargetRepo = monthlyTargetRepo,
       _settingsRepo = settingsRepo,
       _clientRepo = clientRepo,
       _projectClientRepo = projectClientRepo,
       _invoiceRepo = invoiceRepo,
       _pomodoroRepo = pomodoroRepo,
       _httpClientFactory = httpClientFactory {
    _pb = _createClient(serverUrl);
    _ledger = SyncLedger.decode(_settingsRepo.getPocketBaseSyncLedger());

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
    _pb = _createClient(url);
    _lastError = null;
  }

  PocketBase _createClient(String url) => PocketBase(url, httpClientFactory: _httpClientFactory);

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
      _email = email;
      _password = password;
      _saveAuthState();
      await _bindLocalStoreToAccount();
      _startKeepAlive();
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
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _email = null;
    _password = null;
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
    await _settingsRepo.clearAllContextSettings();
    await _clientRepo.deleteAll();
    await _projectClientRepo.deleteAll();
    await _invoiceRepo.deleteAll();
    await _settingsRepo.clearSupplierProfile();
    await _pomodoroRepo?.clearAccountData();
    await _settingsRepo.setPocketBaseLastSync('');
    _ledger.clear();
    await _saveLedger();
  }

  void _saveAuthState() {
    _settingsRepo.setPocketBaseAuthToken(_pb.authStore.token);
    final record = _pb.authStore.record;
    if (record != null) {
      _settingsRepo.setPocketBaseAuthModel(_toJsonString(record.toJson()));
    }
  }

  /// Make sure requests go out with a valid token: refresh it before it
  /// expires, and sign in again with the remembered credentials once it has.
  Future<bool> _ensureAuth() => _authInFlight ??= _refreshAuthIfNeeded().whenComplete(() => _authInFlight = null);

  Future<bool> _refreshAuthIfNeeded() async {
    final token = _pb.authStore.token;
    if (_pb.authStore.isValid) {
      final expiry = tokenExpiry(token);
      if (expiry == null || expiry.isAfter(DateTime.now().add(_tokenRefreshMargin))) return true;
      try {
        await _pb.collection('users').authRefresh();
        _saveAuthState();
        return true;
      } catch (e) {
        debugPrint('[PocketBaseSync] Token refresh failed: $e');
      }
    }

    final email = _email;
    final password = _password;
    if (email == null || password == null) return _pb.authStore.isValid;
    try {
      await _pb.collection('users').authWithPassword(email, password);
      _saveAuthState();
      debugPrint('[PocketBaseSync] Signed in again after the token expired');
      return true;
    } catch (e) {
      debugPrint('[PocketBaseSync] Re-authentication failed: $e');
      _lastError = e.toString();
      return false;
    }
  }

  @visibleForTesting
  static DateTime? tokenExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;
      final exp = payload['exp'];
      final seconds = exp is num ? exp.toInt() : int.tryParse('$exp');
      if (seconds == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    } catch (_) {
      return null;
    }
  }

  /// A desktop app can sit in the tray for longer than a token lives, without
  /// ever being resumed, so the token and the pending queue are kept alive on
  /// a timer rather than only on user activity.
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (_) => _keepAlive());
  }

  Future<void> _keepAlive() async {
    final hadValidToken = _pb.authStore.isValid;
    if (!await _ensureAuth()) return;
    if (!hadValidToken) {
      // Real-time subscriptions were authorized with the expired token.
      await resync();
    } else {
      await _flushPending();
    }
  }

  Future<void> _saveLedger() => _settingsRepo.setPocketBaseSyncLedger(_ledger.encode());

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
      await _subscribeContextCollections();
      await _subscribeClientCollections();
      await _subscribePomodoro();

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
    try {
      await _pb.collection(_contextSettingsCollection).unsubscribe();
      await _pb.collection(_contextDayOverridesCollection).unsubscribe();
    } catch (e) {
      debugPrint('[PocketBaseSync] Error stopping context listeners: $e');
    }
    for (final collection in [_clientsCollection, _projectClientsCollection, _invoicesCollection, _userSettingsCollection, _pomodoroStateCollection, _pomodoroSessionsCollection]) {
      try {
        await _pb.collection(collection).unsubscribe();
      } catch (e) {
        debugPrint('[PocketBaseSync] Error stopping $collection listener: $e');
      }
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
    if (!await _ensureAuth()) return;
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

  Future<void> pushCategory(CategoryModel c) => _pushUpsert('categories', c.id, _categoryToMap(c));

  Future<void> deleteCategory(String id) => _pushDelete('categories', id);

  Future<void> pushProject(ProjectModel p) => _pushUpsert('projects', p.id, _projectToMap(p));

  Future<void> deleteProject(String id) => _pushDelete('projects', id);

  Future<void> pushTask(TaskModel t) => _pushUpsert('tasks', t.id, _taskToMap(t));

  Future<void> deleteTask(String id) => _pushDelete('tasks', id);

  Future<void> pushTimeEntry(TimeEntryModel e) => _pushUpsert('time_entries', e.id, _timeEntryToMap(e));

  Future<void> deleteTimeEntry(String id) => _pushDelete('time_entries', id);

  Future<void> pushRunningTimer(RunningTimerModel t) => _pushUpsert('running_timers', t.id, _runningTimerToMap(t));

  Future<void> deleteRunningTimer(String id) => _pushDelete('running_timers', id);

  Future<void> pushMonthlyTarget(MonthlyHoursTargetModel m) => _pushUpsert('monthly_targets', m.id, _monthlyTargetToMap(m));

  Future<void> deleteMonthlyTarget(String id) => _pushDelete('monthly_targets', id);

  Future<void> pushDayOverride(DateTime date, String type) {
    final dateKey = _dateKey(date);
    return _pushUpsert('day_overrides', dateKey, _dayOverrideToMap(dateKey, type));
  }

  Future<void> deleteDayOverride(DateTime date) => _pushDelete('day_overrides', _dateKey(date));

  /// Push the schedule and month goals of one work context.
  Future<void> pushContextSettings(String contextId) => _pushUpsert(_contextSettingsCollection, contextId, _contextSettingsToMap(contextId));

  Future<void> pushContextDayOverride(String contextId, DateTime date, String type) {
    final itemId = _contextDayKey(contextId, _dateKey(date));
    return _pushUpsert(_contextDayOverridesCollection, itemId, _contextDayOverrideToMap(itemId, type));
  }

  Future<void> deleteContextDayOverride(String contextId, DateTime date) => _pushDelete(_contextDayOverridesCollection, _contextDayKey(contextId, _dateKey(date)));

  Future<void> pushClient(ClientModel c) => _pushUpsert(_clientsCollection, c.id, _clientToMap(c));

  Future<void> deleteClient(String id) => _pushDelete(_clientsCollection, id);

  Future<void> pushProjectClient(ProjectClientModel l) => _pushUpsert(_projectClientsCollection, l.id, _projectClientToMap(l));

  Future<void> deleteProjectClient(String id) => _pushDelete(_projectClientsCollection, id);

  Future<void> pushInvoice(StandaloneInvoiceModel i) => _pushUpsert(_invoicesCollection, i.id, _invoiceToMap(i));

  Future<void> deleteInvoice(String id) => _pushDelete(_invoicesCollection, id);

  Future<void> pushSupplierProfile() {
    final profile = _settingsRepo.getSupplierProfile();
    if (profile == null) return Future.value();
    return _pushUpsert(_userSettingsCollection, _supplierProfileItem, _supplierProfileToMap(profile));
  }

  Future<void> pushPomodoroRecord(PomodoroSessionRecord record) => _pushUpsert(_pomodoroSessionsCollection, record.id, _pomodoroRecordToMap(record));

  Future<void> deletePomodoroRecord(String id) => _pushDelete(_pomodoroSessionsCollection, id);

  Map<String, dynamic> _pomodoroRecordToMap(PomodoroSessionRecord record) => {'item_id': record.id, 'data': record.toJson()};

  PomodoroSessionRecord _pomodoroRecordFromMap(Map<String, dynamic> map) => PomodoroSessionRecord.fromJson(_decodeJsonMap(map['data']));

  Future<void> pushPomodoroSettings() {
    final repo = _pomodoroRepo;
    if (repo == null) return Future.value();
    return _pushUpsert(_userSettingsCollection, _pomodoroSettingsItem, _pomodoroSettingsToMap(repo.getSettings()));
  }

  /// Sends the local pomodoro state after merging it with the server's, so a
  /// stale device never overwrites a newer state or revives an ended session.
  Future<void> pushPomodoroState() async {
    if (_pomodoroRepo == null) return;
    final version = _ledger.markPending(_pomodoroStateCollection, _pomodoroStateItem, PendingOp.upsert);
    await _saveLedger();
    if (!await _ensureAuth()) return;
    if (await _syncPomodoroState()) {
      _ledger.confirm(_pomodoroStateCollection, _pomodoroStateItem);
      _ledger.clearPending(_pomodoroStateCollection, _pomodoroStateItem, version: version);
      await _saveLedger();
    }
  }

  /// Merges the server's pomodoro state into the local one without writing back.
  Future<void> pullPomodoroState({Duration timeout = const Duration(seconds: 3)}) async {
    if (_pomodoroRepo == null || !isSignedIn) return;
    try {
      final existing = await _pb.collection(_pomodoroStateCollection).getList(filter: 'item_id = "$_pomodoroStateItem" && user = "$userId"', perPage: 1).timeout(timeout);
      if (existing.items.isEmpty) return;
      await _applyPomodoroMerge(_pomodoroStateFromRecord(existing.items.first.toJson()));
    } catch (e) {
      debugPrint('[PocketBaseSync] pomodoro pull skipped: $e');
    }
  }

  Future<bool> _syncPomodoroState() async {
    final repo = _pomodoroRepo;
    if (repo == null) return true;
    try {
      final existing = await _pb.collection(_pomodoroStateCollection).getList(filter: 'item_id = "$_pomodoroStateItem" && user = "$userId"', perPage: 1);
      if (existing.items.isEmpty) {
        await _pb.collection(_pomodoroStateCollection).create(body: {..._pomodoroStateToMap(repo.getLiveState()), 'user': userId});
        return true;
      }
      final record = existing.items.first;
      final remote = _pomodoroStateFromRecord(record.toJson());
      final merged = await _applyPomodoroMerge(remote);
      if (merged != remote) await _pb.collection(_pomodoroStateCollection).update(record.id, body: _pomodoroStateToMap(merged));
      return true;
    } catch (e) {
      debugPrint('[PocketBaseSync] pomodoro state sync error: $e');
      return false;
    }
  }

  /// Merges [remote] into the local state, files sessions it supersedes and
  /// returns the merged state.
  Future<PomodoroLiveState> _applyPomodoroMerge(PomodoroLiveState remote) async {
    final repo = _pomodoroRepo!;
    final local = repo.getLiveState();
    final result = PomodoroStateMerge.merge(local, remote);
    var changed = false;
    if (result.state != local) {
      await repo.setLiveState(result.state);
      changed = true;
    }
    for (final superseded in result.superseded) {
      if (repo.hasRecord(superseded.session.id)) continue;
      final advanced = PomodoroEngine.advance(superseded.session, repo.getSettings(), superseded.endedAt);
      final record = advanced.endedRecord ?? PomodoroEngine.stop(advanced.session!, superseded.endedAt, reason: PomodoroEndReason.replaced);
      await repo.addRecord(record);
      unawaited(pushPomodoroRecord(record).catchError((Object e) => debugPrint('[PocketBaseSync] pomodoro record push error: $e')));
      changed = true;
    }
    if (changed) _collectionChangeController.add(SyncCollection.pomodoroState);
    return result.state;
  }

  PomodoroLiveState _pomodoroStateFromRecord(Map<String, dynamic> record) => PomodoroLiveState.fromJson(_decodeJsonMap(record['data']));

  Map<String, dynamic> _pomodoroStateToMap(PomodoroLiveState state) => {'item_id': _pomodoroStateItem, 'data': state.toJson()};

  Map<String, dynamic> _pomodoroSettingsToMap(PomodoroSettings settings) => {'item_id': _pomodoroSettingsItem, 'data': settings.toJson()};

  /// Queue the change before sending it, so a push that cannot go out now
  /// (offline, expired token, server error) is retried instead of forgotten.
  Future<void> _pushUpsert(String collection, String itemId, Map<String, dynamic> data) async {
    final version = _ledger.markPending(collection, itemId, PendingOp.upsert);
    await _saveLedger();
    if (!await _ensureAuth()) return;
    if (await _upsertRecord(collection, itemId, data)) {
      _ledger.confirm(collection, itemId);
      _ledger.clearPending(collection, itemId, version: version);
      await _saveLedger();
    }
  }

  Future<void> _pushDelete(String collection, String itemId) async {
    final version = _ledger.markPending(collection, itemId, PendingOp.delete);
    await _saveLedger();
    if (!await _ensureAuth()) return;
    if (await _deleteRecord(collection, itemId)) {
      _ledger.unconfirm(collection, itemId);
      _ledger.clearPending(collection, itemId, version: version);
      await _saveLedger();
    }
  }

  /// Send every queued change. An upsert sends the record as it is now, so a
  /// record edited several times while offline goes out once, in its final state.
  Future<void> _flushPending() async {
    if (_flushing || _ledger.pendingCount == 0) return;
    _flushing = true;
    try {
      for (final (collection, itemId, op) in _ledger.pendingEntries()) {
        if (!await _ensureAuth()) return;
        final version = _ledger.pendingVersion(collection, itemId);
        if (collection == _pomodoroStateCollection) {
          if (!await _syncPomodoroState()) continue;
          _ledger.confirm(collection, itemId);
        } else if (op == PendingOp.delete) {
          if (!await _deleteRecord(collection, itemId)) continue;
          _ledger.unconfirm(collection, itemId);
        } else {
          final data = _localRecordMap(collection, itemId);
          if (data != null) {
            if (!await _upsertRecord(collection, itemId, data)) continue;
            _ledger.confirm(collection, itemId);
          }
        }
        _ledger.clearPending(collection, itemId, version: version);
      }
    } finally {
      _flushing = false;
      await _saveLedger();
    }
  }

  Map<String, dynamic>? _localRecordMap(String collection, String itemId) {
    switch (collection) {
      case 'categories':
        final c = _categoryRepo.getById(itemId);
        return c == null ? null : _categoryToMap(c);
      case 'projects':
        final p = _projectRepo.getById(itemId);
        return p == null ? null : _projectToMap(p);
      case 'tasks':
        final t = _taskRepo.getById(itemId);
        return t == null ? null : _taskToMap(t);
      case 'time_entries':
        final e = _timeEntryRepo.getById(itemId);
        return e == null ? null : _timeEntryToMap(e);
      case 'running_timers':
        final t = _runningTimerRepo.getById(itemId);
        return t == null ? null : _runningTimerToMap(t);
      case 'monthly_targets':
        final m = _monthlyTargetRepo.getById(itemId);
        return m == null ? null : _monthlyTargetToMap(m);
      case 'day_overrides':
        final type = _settingsRepo.getAllDayOverrides()[itemId];
        return type == null ? null : _dayOverrideToMap(itemId, type);
      case _contextSettingsCollection:
        return _settingsRepo.getContextIdsWithSettings().contains(itemId) ? _contextSettingsToMap(itemId) : null;
      case _contextDayOverridesCollection:
        final type = _settingsRepo.getAllContextDayOverrides()[itemId];
        return type == null ? null : _contextDayOverrideToMap(itemId, type);
      case _clientsCollection:
        final c = _clientRepo.getById(itemId);
        return c == null ? null : _clientToMap(c);
      case _projectClientsCollection:
        final l = _projectClientRepo.getById(itemId);
        return l == null ? null : _projectClientToMap(l);
      case _invoicesCollection:
        final i = _invoiceRepo.getById(itemId);
        return i == null ? null : _invoiceToMap(i);
      case _pomodoroSessionsCollection:
        final record = _pomodoroRepo?.getRecord(itemId);
        return record == null ? null : _pomodoroRecordToMap(record);
      case _userSettingsCollection:
        if (itemId == _pomodoroSettingsItem) {
          final settings = _pomodoroRepo?.getSettings();
          return settings == null ? null : _pomodoroSettingsToMap(settings);
        }
        final profile = itemId == _supplierProfileItem ? _settingsRepo.getSupplierProfile() : null;
        return profile == null ? null : _supplierProfileToMap(profile);
    }
    return null;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BULK — initial upload / download
  // ═════════════════════════════════════════════════════════════════════════

  /// Upload all local data to PocketBase, replacing remote.
  Future<SyncResult> uploadAll({SyncProgressCallback? onProgress}) async {
    if (!await _ensureAuth()) return const SyncResult(error: 'Not signed in');
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

      onProgress?.call('Day overrides…', 0.94);
      final dayOverrides = _settingsRepo.getAllDayOverrides();
      await _replaceRemote('day_overrides', {for (final entry in dayOverrides.entries) entry.key: _dayOverrideToMap(entry.key, entry.value)});

      onProgress?.call('Work contexts…', 0.97);
      await _uploadContextData();

      onProgress?.call('Clients and invoices…', 0.99);
      await _uploadClientData();
      await _uploadPomodoroData();

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
    if (!await _ensureAuth()) return const SyncResult(error: 'Not signed in');
    _suppressListeners = true;
    try {
      onProgress?.call('Uploading local changes…', 0.02);
      await _flushPending();

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

      onProgress?.call('Work contexts…', 0.88);
      final remoteContextSettings = await _downloadOptionalCollection<Map<String, dynamic>>(_contextSettingsCollection, (m) => m);
      final remoteContextOverrides = await _downloadOptionalCollection<MapEntry<String, String>>(_contextDayOverridesCollection, _contextDayOverrideFromMap);

      onProgress?.call('Clients and invoices…', 0.89);
      final remoteClients = await _downloadOptionalCollection(_clientsCollection, _clientFromMap);
      final remoteProjectClients = await _downloadOptionalCollection(_projectClientsCollection, _projectClientFromMap);
      final remoteInvoices = await _downloadOptionalCollection(_invoicesCollection, _invoiceFromMap);
      final remoteUserSettings = await _downloadOptionalCollection<Map<String, dynamic>>(_userSettingsCollection, (m) => m);
      final remotePomodoroStates = _pomodoroRepo == null ? null : await _downloadOptionalCollection<Map<String, dynamic>>(_pomodoroStateCollection, (m) => m);
      final remotePomodoroRecords = _pomodoroRepo == null ? null : await _downloadOptionalCollection(_pomodoroSessionsCollection, _pomodoroRecordFromMap);

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
        if (remoteClients != null) {
          await _replaceLocal<ClientModel>(
            _clientsCollection,
            remoteClients,
            _clientRepo.getAll().map((c) => c.id).toSet(),
            (c) => _clientRepo.add(c),
            (id) => _clientRepo.delete(id),
            (c) => c.id,
          );
        }
        if (remoteProjectClients != null) {
          await _replaceLocal<ProjectClientModel>(
            _projectClientsCollection,
            remoteProjectClients,
            _projectClientRepo.getAll().map((l) => l.id).toSet(),
            (l) => _projectClientRepo.add(l),
            (id) => _projectClientRepo.delete(id),
            (l) => l.id,
          );
        }
        final pomodoroRepo = _pomodoroRepo;
        if (remotePomodoroRecords != null && pomodoroRepo != null) {
          await _replaceLocal<PomodoroSessionRecord>(
            _pomodoroSessionsCollection,
            remotePomodoroRecords,
            pomodoroRepo.getRecords().map((r) => r.id).toSet(),
            (r) => pomodoroRepo.addRecord(r),
            (id) => pomodoroRepo.deleteRecord(id),
            (r) => r.id,
          );
        }
        if (remoteInvoices != null) {
          await _replaceLocal<StandaloneInvoiceModel>(
            _invoicesCollection,
            remoteInvoices,
            _invoiceRepo.getAll().map((i) => i.id).toSet(),
            (i) => _invoiceRepo.add(i),
            (id) => _invoiceRepo.delete(id),
            (i) => i.id,
          );
        }
      });

      if (remoteUserSettings != null) await _applyRemoteUserSettings(remoteUserSettings);
      if (remotePomodoroStates != null) await _applyRemotePomodoroStates(remotePomodoroStates);

      // Day overrides are cheap settings keys, not records — but the same
      // "empty remote must not wipe local" rule applies.
      final localOverrides = _settingsRepo.getAllDayOverrides();
      if (remoteDayOverrides.isEmpty && localOverrides.isNotEmpty) {
        _reportGuard(SyncGuardReport(collection: 'day_overrides', blockedDeletions: localOverrides.length, localCount: localOverrides.length, remoteCount: 0));
      } else {
        await _settingsRepo.restoreAllDayOverrides(_reconcileKeyed('day_overrides', Map.fromEntries(remoteDayOverrides), localOverrides));
      }

      // Context settings are only ever upserted: a context whose record the
      // server does not have keeps its local schedule instead of losing it.
      if (remoteContextSettings != null) {
        for (final settings in remoteContextSettings) {
          final contextId = settings['item_id'] as String? ?? '';
          if (_ledger.pendingOp(_contextSettingsCollection, contextId) != null) continue;
          await _applyContextSettings(settings);
        }
      }

      final localContextOverrides = _settingsRepo.getAllContextDayOverrides();
      if (remoteContextOverrides != null) {
        if (remoteContextOverrides.isEmpty && localContextOverrides.isNotEmpty) {
          _reportGuard(
            SyncGuardReport(collection: _contextDayOverridesCollection, blockedDeletions: localContextOverrides.length, localCount: localContextOverrides.length, remoteCount: 0),
          );
        } else {
          await _settingsRepo.restoreAllContextDayOverrides(_reconcileKeyed(_contextDayOverridesCollection, Map.fromEntries(remoteContextOverrides), localContextOverrides));
        }
      }

      await _saveLedger();
      onProgress?.call('Uploading local changes…', 0.95);
      await _flushPending();

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
    for (final coll in [
      'categories',
      'projects',
      'tasks',
      'time_entries',
      'running_timers',
      'monthly_targets',
      'day_overrides',
      _contextSettingsCollection,
      _contextDayOverridesCollection,
    ]) {
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
        _settingsRepo.getAllDayOverrides().length +
        _settingsRepo.getContextIdsWithSettings().length +
        _settingsRepo.getAllContextDayOverrides().length;
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
      _handleEvent<CategoryModel>('categories', e, _categoryFromMap, (c) => _categoryRepo.add(c), (id) => _categoryRepo.delete(id));
      _collectionChangeController.add(SyncCollection.categories);
    }, filter: 'user = "$userId"');
  }

  Future<void> _subscribeProjects() async {
    await _pb.collection('projects').subscribe('*', (e) {
      if (_suppressListeners) return;
      _handleEvent<ProjectModel>('projects', e, _projectFromMap, (p) => _projectRepo.add(p), (id) => _projectRepo.delete(id));
      _collectionChangeController.add(SyncCollection.projects);
    }, filter: 'user = "$userId"');
  }

  Future<void> _subscribeTasks() async {
    await _pb.collection('tasks').subscribe('*', (e) {
      if (_suppressListeners) return;
      _handleEvent<TaskModel>('tasks', e, _taskFromMap, (t) => _taskRepo.add(t), (id) => _taskRepo.delete(id));
      _collectionChangeController.add(SyncCollection.tasks);
    }, filter: 'user = "$userId"');
  }

  Future<void> _subscribeTimeEntries() async {
    await _pb.collection('time_entries').subscribe('*', (e) {
      if (_suppressListeners) return;
      _handleEvent<TimeEntryModel>('time_entries', e, _timeEntryFromMap, (entry) => _timeEntryRepo.add(entry), (id) => _timeEntryRepo.delete(id));
      _collectionChangeController.add(SyncCollection.timeEntries);
    }, filter: 'user = "$userId"');
  }

  Future<void> _subscribeRunningTimers() async {
    await _pb.collection('running_timers').subscribe('*', (e) {
      if (_suppressListeners) return;
      _handleEvent<RunningTimerModel>('running_timers', e, _runningTimerFromMap, (t) => _runningTimerRepo.start(t), (id) => _runningTimerRepo.stop(id));
      _collectionChangeController.add(SyncCollection.runningTimers);
    }, filter: 'user = "$userId"');
  }

  Future<void> _subscribeMonthlyTargets() async {
    await _pb.collection('monthly_targets').subscribe('*', (e) {
      if (_suppressListeners) return;
      _handleEvent<MonthlyHoursTargetModel>('monthly_targets', e, _monthlyTargetFromMap, (m) => _monthlyTargetRepo.add(m), (id) => _monthlyTargetRepo.delete(id));
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
      if (date == null || !_acceptRemoteChange('day_overrides', itemId, e.action)) return;

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

  /// Subscribe to the optional context collections.
  ///
  /// A server without them must not leave the client in the error state, so a
  /// failure here is logged and the rest of the sync carries on.
  Future<void> _subscribeContextCollections() async {
    try {
      await _pb.collection(_contextSettingsCollection).subscribe('*', (e) async {
        if (_suppressListeners) return;
        final record = e.record;
        if (record == null || e.action == 'delete') return;
        if (!_acceptRemoteChange(_contextSettingsCollection, record.getStringValue('item_id'), e.action)) return;
        await _applyContextSettings(record.toJson());
        _collectionChangeController.add(SyncCollection.contextSettings);
      }, filter: 'user = "$userId"');

      await _pb.collection(_contextDayOverridesCollection).subscribe('*', (e) async {
        if (_suppressListeners) return;
        final record = e.record;
        if (record == null) return;

        final contextId = record.getStringValue('context_id');
        final date = _parseDateKeyOrNull(record.getStringValue('date'));
        if (contextId.isEmpty || date == null) return;
        if (!_acceptRemoteChange(_contextDayOverridesCollection, record.getStringValue('item_id'), e.action)) return;

        switch (e.action) {
          case 'create':
          case 'update':
            final type = record.getStringValue('override_type');
            if (type == 'off' || type == 'work') {
              await _settingsRepo.setContextDayOverride(contextId, date, type);
              _collectionChangeController.add(SyncCollection.contextDayOverrides);
            }
          case 'delete':
            await _settingsRepo.setContextDayOverride(contextId, date, null);
            _collectionChangeController.add(SyncCollection.contextDayOverrides);
        }
      }, filter: 'user = "$userId"');
    } catch (e) {
      debugPrint('[PocketBaseSync] Context collections unavailable, real-time sync for them is off: $e');
    }
  }

  /// Real-time updates for clients, their project links, invoices and the
  /// supplier profile. Like the context collections, a server without them
  /// only turns their real-time sync off.
  Future<void> _subscribeClientCollections() async {
    // Subscribing adds the topic to the shared realtime connection, so a
    // collection the server does not have is never subscribed to at all.
    if (!await _serverHasCollection(_clientsCollection)) return;
    try {
      await _pb.collection(_clientsCollection).subscribe('*', (e) {
        if (_suppressListeners) return;
        _handleEvent<ClientModel>(_clientsCollection, e, _clientFromMap, (c) => _clientRepo.add(c), (id) => _clientRepo.delete(id));
        _collectionChangeController.add(SyncCollection.clients);
      }, filter: 'user = "$userId"');

      await _pb.collection(_projectClientsCollection).subscribe('*', (e) {
        if (_suppressListeners) return;
        _handleEvent<ProjectClientModel>(_projectClientsCollection, e, _projectClientFromMap, (l) => _projectClientRepo.add(l), (id) => _projectClientRepo.delete(id));
        _collectionChangeController.add(SyncCollection.projectClients);
      }, filter: 'user = "$userId"');

      await _pb.collection(_invoicesCollection).subscribe('*', (e) {
        if (_suppressListeners) return;
        _handleEvent<StandaloneInvoiceModel>(_invoicesCollection, e, _invoiceFromMap, (i) => _invoiceRepo.add(i), (id) => _invoiceRepo.delete(id));
        _collectionChangeController.add(SyncCollection.invoices);
      }, filter: 'user = "$userId"');

      await _pb.collection(_userSettingsCollection).subscribe('*', (e) async {
        if (_suppressListeners) return;
        final record = e.record;
        if (record == null || e.action == 'delete') return;
        await _applyRemoteUserSettings([record.toJson()], complete: false);
        _collectionChangeController.add(SyncCollection.supplierProfile);
      }, filter: 'user = "$userId"');
    } catch (e) {
      debugPrint('[PocketBaseSync] Client collections unavailable, real-time sync for them is off: $e');
    }
  }

  /// Real-time pomodoro state. Every event is merged, never applied blindly;
  /// when the local side wins, the merged state is sent back.
  Future<void> _subscribePomodoro() async {
    if (_pomodoroRepo == null || !await _serverHasCollection(_pomodoroStateCollection)) return;
    try {
      await _pb.collection(_pomodoroStateCollection).subscribe('*', (e) async {
        if (_suppressListeners) return;
        final record = e.record;
        if (record == null || e.action == 'delete' || record.getStringValue('item_id') != _pomodoroStateItem) return;
        final remote = _pomodoroStateFromRecord(record.toJson());
        final merged = await _applyPomodoroMerge(remote);
        if (merged != remote) await pushPomodoroState();
      }, filter: 'user = "$userId"');
      if (await _serverHasCollection(_pomodoroSessionsCollection)) {
        await _pb.collection(_pomodoroSessionsCollection).subscribe('*', (e) {
          if (_suppressListeners) return;
          final repo = _pomodoroRepo;
          _handleEvent<PomodoroSessionRecord>(_pomodoroSessionsCollection, e, _pomodoroRecordFromMap, repo.addRecord, repo.deleteRecord);
          _collectionChangeController.add(SyncCollection.pomodoroSessions);
        }, filter: 'user = "$userId"');
      }
    } catch (e) {
      debugPrint('[PocketBaseSync] Pomodoro state unavailable, real-time sync for it is off: $e');
    }
  }

  Future<bool> _serverHasCollection(String collection) async {
    try {
      await _pb.collection(collection).getList(filter: 'user = "$userId"', perPage: 1);
      return true;
    } on ClientException catch (e) {
      debugPrint('[PocketBaseSync] Collection "$collection" unavailable (${e.statusCode}), real-time sync for it is off');
      return false;
    }
  }

  /// Apply downloaded `user_settings` records. Each item is a single record
  /// per account: the side edited later wins, and a local item the server does
  /// not have yet is queued for upload instead of being dropped. A real-time
  /// event carries one record, so [complete] is false and absent items are
  /// left alone.
  Future<void> _applyRemoteUserSettings(List<Map<String, dynamic>> records, {bool complete = true}) async {
    final byItem = <String, Map<String, dynamic>>{for (final r in records) (r['item_id'] as String? ?? ''): r};
    if (complete || byItem.containsKey(_supplierProfileItem)) await _applyRemoteSupplierProfile(byItem[_supplierProfileItem]);
    if (_pomodoroRepo != null && (complete || byItem.containsKey(_pomodoroSettingsItem))) await _applyRemotePomodoroSettings(byItem[_pomodoroSettingsItem]);
    await _saveLedger();
  }

  Future<void> _applyRemoteSupplierProfile(Map<String, dynamic>? remoteProfileRecord) async {
    final local = _settingsRepo.getSupplierProfile();
    if (_ledger.pendingOp(_userSettingsCollection, _supplierProfileItem) != null) return;

    if (remoteProfileRecord == null) {
      if (local != null) _ledger.markPending(_userSettingsCollection, _supplierProfileItem, PendingOp.upsert);
      return;
    }

    _ledger.confirm(_userSettingsCollection, _supplierProfileItem);
    final remote = SupplierProfile.fromJson(_decodeJsonMap(remoteProfileRecord['data']));
    if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
      await _settingsRepo.setSupplierProfile(remote);
    } else if (local.updatedAt.isAfter(remote.updatedAt)) {
      _ledger.markPending(_userSettingsCollection, _supplierProfileItem, PendingOp.upsert);
    }
  }

  Future<void> _applyRemotePomodoroSettings(Map<String, dynamic>? record) async {
    final repo = _pomodoroRepo!;
    if (_ledger.pendingOp(_userSettingsCollection, _pomodoroSettingsItem) != null) return;
    final local = repo.getSettings();

    if (record == null) {
      if (local.updatedAt != null) _ledger.markPending(_userSettingsCollection, _pomodoroSettingsItem, PendingOp.upsert);
      return;
    }

    _ledger.confirm(_userSettingsCollection, _pomodoroSettingsItem);
    final remote = PomodoroSettings.fromJson(_decodeJsonMap(record['data']));
    final remoteAt = remote.updatedAt;
    final localAt = local.updatedAt;
    if (remoteAt != null && (localAt == null || remoteAt.isAfter(localAt))) {
      await repo.setSettings(remote);
      _collectionChangeController.add(SyncCollection.pomodoroSettings);
    } else if (localAt != null && (remoteAt == null || localAt.isAfter(remoteAt))) {
      _ledger.markPending(_userSettingsCollection, _pomodoroSettingsItem, PendingOp.upsert);
    }
  }

  /// The downloaded pomodoro state merges into the local one; a local state the
  /// server does not have yet is queued for upload.
  Future<void> _applyRemotePomodoroStates(List<Map<String, dynamic>> records) async {
    Map<String, dynamic>? record;
    for (final r in records) {
      if (r['item_id'] == _pomodoroStateItem) record = r;
    }
    if (record == null) {
      if (!_pomodoroRepo!.getLiveState().isEmpty) _ledger.markPending(_pomodoroStateCollection, _pomodoroStateItem, PendingOp.upsert);
      return;
    }
    final remote = _pomodoroStateFromRecord(record);
    final merged = await _applyPomodoroMerge(remote);
    if (merged != remote) {
      _ledger.markPending(_pomodoroStateCollection, _pomodoroStateItem, PendingOp.upsert);
    } else {
      _ledger.confirm(_pomodoroStateCollection, _pomodoroStateItem);
    }
  }

  /// Pomodoro settings and state on a full upload. Failures are logged: the
  /// collection is optional on the server.
  Future<void> _uploadPomodoroData() async {
    final repo = _pomodoroRepo;
    if (repo == null) return;
    if (repo.getSettings().updatedAt != null && await _upsertRecord(_userSettingsCollection, _pomodoroSettingsItem, _pomodoroSettingsToMap(repo.getSettings()))) {
      _ledger.confirm(_userSettingsCollection, _pomodoroSettingsItem);
      _ledger.clearPending(_userSettingsCollection, _pomodoroSettingsItem, version: _ledger.pendingVersion(_userSettingsCollection, _pomodoroSettingsItem));
    }
    for (final record in repo.getRecords()) {
      if (await _upsertRecord(_pomodoroSessionsCollection, record.id, _pomodoroRecordToMap(record))) {
        _ledger.confirm(_pomodoroSessionsCollection, record.id);
        _ledger.clearPending(_pomodoroSessionsCollection, record.id, version: _ledger.pendingVersion(_pomodoroSessionsCollection, record.id));
      }
    }
    if (!repo.getLiveState().isEmpty && await _syncPomodoroState()) {
      _ledger.confirm(_pomodoroStateCollection, _pomodoroStateItem);
      _ledger.clearPending(_pomodoroStateCollection, _pomodoroStateItem, version: _ledger.pendingVersion(_pomodoroStateCollection, _pomodoroStateItem));
    }
    await _saveLedger();
  }

  /// Push clients, links, invoices and the supplier profile. Failures are
  /// logged, not thrown: the collections are optional on the server.
  Future<void> _uploadClientData() async {
    final collections = <String, Map<String, Map<String, dynamic>>>{
      _clientsCollection: {for (final c in _clientRepo.getAll()) c.id: _clientToMap(c)},
      _projectClientsCollection: {for (final l in _projectClientRepo.getAll()) l.id: _projectClientToMap(l)},
      _invoicesCollection: {for (final i in _invoiceRepo.getAll()) i.id: _invoiceToMap(i)},
    };
    for (final entry in collections.entries) {
      try {
        await _replaceRemote(entry.key, entry.value);
      } catch (e) {
        debugPrint('[PocketBaseSync] ${entry.key} upload skipped: $e');
      }
    }
    final profile = _settingsRepo.getSupplierProfile();
    if (profile != null && await _upsertRecord(_userSettingsCollection, _supplierProfileItem, _supplierProfileToMap(profile))) {
      _ledger.confirm(_userSettingsCollection, _supplierProfileItem);
      _ledger.clearPending(_userSettingsCollection, _supplierProfileItem, version: _ledger.pendingVersion(_userSettingsCollection, _supplierProfileItem));
      await _saveLedger();
    }
  }

  void _handleEvent<T>(
    String collection,
    RecordSubscriptionEvent event,
    T Function(Map<String, dynamic>) fromMap,
    Future<void> Function(T) upsert,
    Future<void> Function(String) delete,
  ) {
    final record = event.record;
    if (record == null) return;
    final itemId = record.getStringValue('item_id');
    if (itemId.isEmpty || !_acceptRemoteChange(collection, itemId, event.action)) return;

    switch (event.action) {
      case 'create':
      case 'update':
        final item = fromMap(record.toJson());
        upsert(item);
        break;
      case 'delete':
        _journalled(DeleteSource.syncRealtime, () => delete(itemId));
        break;
    }
  }

  /// Records what a real-time event says the server holds. Returns false when a
  /// local change to the same record has not been sent yet: it must win over
  /// the remote state, not be overwritten by it.
  bool _acceptRemoteChange(String collection, String itemId, String action) {
    if (_ledger.pendingOp(collection, itemId) != null) return false;
    if (action == 'delete') {
      _ledger.unconfirm(collection, itemId);
    } else {
      _ledger.confirm(collection, itemId);
    }
    _saveLedger();
    return true;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════════════════════════════════

  /// Upsert a record — try update first, create if not found.
  Future<bool> _upsertRecord(String collection, String itemId, Map<String, dynamic> data) async {
    try {
      // Search for existing record by item_id
      final existing = await _pb.collection(collection).getList(filter: 'item_id = "$itemId" && user = "$userId"', perPage: 1);
      if (existing.items.isNotEmpty) {
        await _pb.collection(collection).update(existing.items.first.id, body: data);
      } else {
        await _pb.collection(collection).create(body: {...data, 'user': userId});
      }
      return true;
    } catch (e) {
      debugPrint('[PocketBaseSync] upsert $collection/$itemId error: $e');
      return false;
    }
  }

  /// Delete a record by item_id.
  Future<bool> _deleteRecord(String collection, String itemId) async {
    try {
      final existing = await _pb.collection(collection).getList(filter: 'item_id = "$itemId" && user = "$userId"', perPage: 1);
      if (existing.items.isNotEmpty) {
        await _pb.collection(collection).delete(existing.items.first.id);
      }
      return true;
    } catch (e) {
      debugPrint('[PocketBaseSync] delete $collection/$itemId error: $e');
      return false;
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

    _ledger.setConfirmed(collection, {...items.keys, ...existingRecords.keys});
    for (final itemId in items.keys) {
      _ledger.clearPending(collection, itemId, version: _ledger.pendingVersion(collection, itemId));
    }
    await _saveLedger();

    // Delete remote orphans — but only if this looks like a real deletion and
    // not a truncated/empty local store about to wipe a healthy server.
    final orphans = existingRecords.values.toList();
    if (SyncGuard.blocks(deleteCount: orphans.length, localCount: remoteCountBefore, remoteCount: items.length)) {
      _reportGuard(SyncGuardReport(collection: collection, blockedDeletions: orphans.length, localCount: items.length, remoteCount: remoteCountBefore, remoteSide: true));
      return;
    }

    for (final entry in existingRecords.entries) {
      await _pb.collection(collection).delete(entry.value);
      _ledger.unconfirm(collection, entry.key);
      _ledger.clearPending(collection, entry.key, version: _ledger.pendingVersion(collection, entry.key));
    }
    await _saveLedger();
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

  /// Like [_downloadCollection], but returns null when the server has no such
  /// collection or will not serve it. Lets a client whose schema is newer than
  /// the server's sync everything else instead of aborting.
  Future<List<T>?> _downloadOptionalCollection<T>(String collection, T Function(Map<String, dynamic>) fromMap) async {
    try {
      return await _downloadCollection(collection, fromMap);
    } on ClientException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 403) {
        debugPrint('[PocketBaseSync] Collection "$collection" unavailable (${e.statusCode}), skipping');
        return null;
      }
      rethrow;
    }
  }

  /// Push every work context's schedule and day overrides.
  ///
  /// Failures are logged, not thrown: the context collections are optional and
  /// must never take the rest of an upload down with them.
  Future<void> _uploadContextData() async {
    try {
      for (final contextId in _settingsRepo.getContextIdsWithSettings()) {
        await _upsertRecord(_contextSettingsCollection, contextId, _contextSettingsToMap(contextId));
      }

      await _replaceRemote(_contextDayOverridesCollection, {
        for (final entry in _settingsRepo.getAllContextDayOverrides().entries) entry.key: _contextDayOverrideToMap(entry.key, entry.value),
      });
    } catch (e) {
      debugPrint('[PocketBaseSync] Context data upload skipped: $e');
    }
  }

  /// Reconcile a local collection against the freshly downloaded remote list.
  ///
  /// Upserts are always safe. Deletions are not: a record missing from
  /// [remoteItems] means "deleted remotely" *or* "the server failed to tell us
  /// about it", and we cannot distinguish the two. So a suspiciously large
  /// deletion batch is refused and reported rather than applied — see [SyncGuard].
  ///
  /// Records with unsent local changes keep their local state, and only records
  /// the server is known to have had are candidates for deletion — see [SyncLedger].
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
      final id = getId(item);
      remoteIds.add(id);
      if (_ledger.pendingOp(collection, id) != null) continue;
      await upsert(item);
    }

    final plan = _ledger.plan(collection, localIds: localIds, remoteIds: remoteIds);
    _ledger.setConfirmed(collection, remoteIds);
    for (final id in plan.upload) {
      _ledger.markPending(collection, id, PendingOp.upsert);
    }

    final toDelete = plan.deleteLocally;
    if (SyncGuard.blocks(deleteCount: toDelete.length, localCount: localIds.length, remoteCount: remoteItems.length)) {
      _reportGuard(SyncGuardReport(collection: collection, blockedDeletions: toDelete.length, localCount: localIds.length, remoteCount: remoteItems.length));
      return;
    }

    for (final id in toDelete) {
      await delete(id);
    }
  }

  /// [_replaceLocal] for collections kept locally as one key → value map.
  Map<String, String> _reconcileKeyed(String collection, Map<String, String> remote, Map<String, String> local) {
    final plan = _ledger.plan(collection, localIds: local.keys.toSet(), remoteIds: remote.keys.toSet());
    final merged = <String, String>{};
    remote.forEach((key, value) {
      switch (_ledger.pendingOp(collection, key)) {
        case PendingOp.delete:
          break;
        case PendingOp.upsert:
          merged[key] = local[key] ?? value;
        case null:
          merged[key] = value;
      }
    });
    for (final key in plan.upload) {
      merged[key] = local[key]!;
      _ledger.markPending(collection, key, PendingOp.upsert);
    }
    _ledger.setConfirmed(collection, remote.keys);
    return merged;
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

  Map<String, dynamic> _dayOverrideToMap(String dateKey, String type) => {'item_id': dateKey, 'date': dateKey, 'override_type': type};

  MapEntry<String, String> _dayOverrideFromMap(Map<String, dynamic> m) {
    final date = m['date'] as String? ?? m['item_id'] as String? ?? '';
    final type = m['override_type'] as String? ?? '';
    return MapEntry(date, type);
  }

  // --- Work contexts ---

  Map<String, dynamic> _contextSettingsToMap(String contextId) => {
    'item_id': contextId,
    'context_id': contextId,
    'use_own_schedule': _settingsRepo.getContextUsesOwnSchedule(contextId),
    'schedule': jsonEncode(_settingsRepo.getContextScheduleMap(contextId)),
    'month_targets': jsonEncode(_settingsRepo.getContextMonthTargets(contextId)),
  };

  Future<void> _applyContextSettings(Map<String, dynamic> m) async {
    final contextId = m['item_id'] as String? ?? m['context_id'] as String? ?? '';
    if (contextId.isEmpty) return;

    await _settingsRepo.setContextUsesOwnSchedule(contextId, m['use_own_schedule'] as bool? ?? false);

    final schedule = _decodeJsonMap(m['schedule']);
    if (schedule.isNotEmpty) await _settingsRepo.restoreContextScheduleMap(contextId, schedule);

    await _settingsRepo.restoreContextMonthTargets(contextId, _decodeJsonMap(m['month_targets']));
  }

  /// `<contextId>|<YYYY-MM-DD>` — the key both the remote `item_id` and the
  /// local override map use.
  MapEntry<String, String> _contextDayOverrideFromMap(Map<String, dynamic> m) {
    final contextId = m['context_id'] as String? ?? '';
    final date = m['date'] as String? ?? '';
    final type = m['override_type'] as String? ?? '';
    return MapEntry(_contextDayKey(contextId, date), type);
  }

  static String _contextDayKey(String contextId, String dateKey) => '$contextId${AppConstants.contextKeySeparator}$dateKey';

  Map<String, dynamic> _contextDayOverrideToMap(String itemId, String type) => {
    'item_id': itemId,
    'context_id': itemId.split(AppConstants.contextKeySeparator).first,
    'date': itemId.split(AppConstants.contextKeySeparator).last,
    'override_type': type,
  };

  // --- Client ---
  Map<String, dynamic> _clientToMap(ClientModel c) => {
    'item_id': c.id,
    'name': c.name,
    'address_line1': c.addressLine1,
    'address_line2': c.addressLine2,
    'ico': c.ico,
    'dic': c.dic,
    'email': c.email,
    'phone': c.phone,
    'notes': c.notes,
    'is_archived': c.isArchived,
    'created_at': c.createdAt.toIso8601String(),
  };

  ClientModel _clientFromMap(Map<String, dynamic> m) => ClientModel(
    id: m['item_id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    addressLine1: m['address_line1'] as String? ?? '',
    addressLine2: m['address_line2'] as String? ?? '',
    ico: m['ico'] as String? ?? '',
    dic: m['dic'] as String? ?? '',
    email: m['email'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    notes: m['notes'] as String? ?? '',
    isArchived: m['is_archived'] as bool? ?? false,
    createdAt: _parseDate(m['created_at']),
  );

  // --- Project ↔ client link ---
  Map<String, dynamic> _projectClientToMap(ProjectClientModel l) => {
    'item_id': l.id,
    'project_id': l.projectId,
    'client_id': l.clientId,
    'service_description': l.serviceDescription,
    'created_at': l.createdAt.toIso8601String(),
    'position': l.position,
  };

  ProjectClientModel _projectClientFromMap(Map<String, dynamic> m) => ProjectClientModel(
    id: m['item_id'] as String? ?? '',
    projectId: m['project_id'] as String? ?? '',
    clientId: m['client_id'] as String? ?? '',
    serviceDescription: m['service_description'] as String? ?? '',
    createdAt: _parseDate(m['created_at']),
    position: (m['position'] as num?)?.toInt() ?? 0,
  );

  // --- Invoice: searchable columns plus the full invoice as JSON ---
  Map<String, dynamic> _invoiceToMap(StandaloneInvoiceModel i) => {
    'item_id': i.id,
    'invoice_number': i.invoiceNumber,
    'invoice_type': i.invoiceType,
    'client_id': i.clientId ?? '',
    'issue_date': i.issueDate.toIso8601String(),
    'data': i.toJson(),
  };

  StandaloneInvoiceModel _invoiceFromMap(Map<String, dynamic> m) {
    final data = _decodeJsonMap(m['data']);
    return StandaloneInvoiceModel.fromJson({...data, 'id': m['item_id'] as String? ?? data['id']});
  }

  // --- Supplier profile (one user_settings record) ---
  Map<String, dynamic> _supplierProfileToMap(SupplierProfile p) => {'item_id': _supplierProfileItem, 'data': p.toJson()};

  static Map<String, dynamic> _decodeJsonMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (e) {
        debugPrint('[PocketBaseSync] Malformed context JSON: $e');
      }
    }
    return const {};
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
    _keepAliveTimer?.cancel();
    await stopListeners();
    await _statusController.close();
    await _collectionChangeController.close();
    await _authStateController.close();
    await _guardController.close();
    await _accountSwitchController.close();
  }
}
