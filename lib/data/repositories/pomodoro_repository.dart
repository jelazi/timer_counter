import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../models/pomodoro_session.dart';
import '../models/pomodoro_settings.dart';

class PomodoroRepository {
  static const _settingsKey = 'settings';
  static const _liveStateKey = 'live_state';
  static const _legacySessionKey = 'session';
  static const _showOnTimeTrackingKey = 'show_on_time_tracking';
  static const _soundsOnDeviceKey = 'sounds_on_device';
  static const _notificationsOnDeviceKey = 'notifications_on_device';
  static const _exactAlarmsAskedKey = 'exact_alarms_asked';
  static const _mobileTabKey = 'mobile_tab';

  late Box<dynamic> _box;
  late Box<dynamic> _records;

  Future<void> init() async {
    _box = await Hive.openBox(AppConstants.pomodoroBox);
    _records = await Hive.openBox(AppConstants.pomodoroSessionsBox);
  }

  PomodoroSettings getSettings() {
    final raw = _box.get(_settingsKey);
    if (raw is! Map) return const PomodoroSettings();
    return PomodoroSettings.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> setSettings(PomodoroSettings settings) => _box.put(_settingsKey, settings.toJson());

  PomodoroLiveState getLiveState() {
    final raw = _box.get(_liveStateKey);
    if (raw is Map) return PomodoroLiveState.fromJson(Map<String, dynamic>.from(raw));
    final legacy = _box.get(_legacySessionKey);
    if (legacy is Map) {
      final session = PomodoroSession.fromJson(Map<String, dynamic>.from(legacy));
      return PomodoroLiveState(session: session, updatedAt: session.updatedAt);
    }
    return PomodoroLiveState.empty;
  }

  Future<void> setLiveState(PomodoroLiveState state) async {
    await _box.put(_liveStateKey, state.toJson());
    if (_box.containsKey(_legacySessionKey)) await _box.delete(_legacySessionKey);
  }

  PomodoroSession? getSession() => getLiveState().session;

  bool getShowOnTimeTracking() => _box.get(_showOnTimeTrackingKey, defaultValue: true) as bool;

  Future<void> setShowOnTimeTracking(bool value) => _box.put(_showOnTimeTrackingKey, value);

  bool getSoundsOnDevice() => _box.get(_soundsOnDeviceKey, defaultValue: true) as bool;

  Future<void> setSoundsOnDevice(bool value) => _box.put(_soundsOnDeviceKey, value);

  bool getNotificationsOnDevice() => _box.get(_notificationsOnDeviceKey, defaultValue: true) as bool;

  Future<void> setNotificationsOnDevice(bool value) => _box.put(_notificationsOnDeviceKey, value);

  bool getMobileTab() => _box.get(_mobileTabKey, defaultValue: false) as bool;

  Future<void> setMobileTab(bool value) => _box.put(_mobileTabKey, value);

  bool getExactAlarmsAsked() => _box.get(_exactAlarmsAskedKey, defaultValue: false) as bool;

  Future<void> setExactAlarmsAsked() => _box.put(_exactAlarmsAskedKey, true);

  List<PomodoroSessionRecord> getRecords() {
    final records = <PomodoroSessionRecord>[];
    for (final raw in _records.values) {
      if (raw is Map) records.add(PomodoroSessionRecord.fromJson(Map<String, dynamic>.from(raw)));
    }
    records.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return records;
  }

  bool hasRecord(String id) => _records.containsKey(id);

  Future<void> addRecord(PomodoroSessionRecord record) => _records.put(record.id, record.toJson());

  PomodoroSessionRecord? getRecord(String id) {
    final raw = _records.get(id);
    return raw is Map ? PomodoroSessionRecord.fromJson(Map<String, dynamic>.from(raw)) : null;
  }

  Future<void> deleteRecord(String id) => _records.delete(id);

  /// Drops the account's pomodoro data; the per-device preferences stay.
  Future<void> clearAccountData() async {
    await _box.delete(_settingsKey);
    await _box.delete(_liveStateKey);
    await _box.delete(_legacySessionKey);
    await _records.clear();
  }
}
