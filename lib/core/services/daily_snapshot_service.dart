import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/settings_repository.dart';
import '../utils/platform_utils.dart';
import 'backup_service.dart';

/// How often an automatic snapshot is taken.
enum SnapshotFrequency {
  off,
  launch,
  daily,
  weekly;

  static SnapshotFrequency parse(String? value) => SnapshotFrequency.values.firstWhere((f) => f.name == value, orElse: () => SnapshotFrequency.daily);
}

/// A snapshot file on disk.
@immutable
class SnapshotInfo {
  final String path;

  /// Calendar day the snapshot was taken, parsed from the file name.
  final DateTime date;
  final int sizeBytes;

  const SnapshotInfo({required this.path, required this.date, required this.sizeBytes});
}

/// Writes a full local copy of the dataset once per configured interval.
///
/// This exists because cloud sync reconciliation can destroy local records when
/// the server under-reports what it has. Snapshots are taken **before** sync
/// runs, so the last-known-good state is on disk before anything can eat it,
/// and at most one snapshot is written per day — a corrupted post-sync state
/// can never overwrite the good snapshot taken earlier the same day.
///
/// No-ops on web, which has no writable filesystem.
class DailySnapshotService {
  static const String _fileNamePrefix = 'snapshot_';

  /// A snapshot taken on the 1st of a month is kept for a year regardless of
  /// the daily retention window, so a slow-burning loss is still recoverable.
  static const int _monthlyRetentionMonths = 12;

  final BackupService _backupService;
  final SettingsRepository _settingsRepository;

  Directory? _dir;

  DailySnapshotService({required BackupService backupService, required SettingsRepository settingsRepository})
    : _backupService = backupService,
      _settingsRepository = settingsRepository;

  Future<void> init() async {
    if (PlatformUtils.isWeb) return;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/snapshots');
      if (!await dir.exists()) await dir.create(recursive: true);
      _dir = dir;
    } catch (e) {
      debugPrint('[Snapshot] Init failed: $e');
    }
  }

  /// Absolute path of the snapshot directory, for "open folder" in the UI.
  String? get directoryPath => _dir?.path;

  SnapshotFrequency get frequency => SnapshotFrequency.parse(_settingsRepository.getSnapshotFrequency());

  /// Take a snapshot if the configured interval has elapsed.
  ///
  /// Returns the file path when one was written, or null when it wasn't due.
  /// Call this BEFORE any sync runs.
  Future<String?> takeSnapshotIfDue() async {
    if (_dir == null) return null;
    if (!_isDue()) return null;

    try {
      return await takeSnapshotNow();
    } catch (e) {
      // A failed snapshot must never block app startup.
      debugPrint('[Snapshot] Failed to take snapshot: $e');
      return null;
    }
  }

  /// Write a snapshot for today, overwriting today's if it already exists.
  Future<String> takeSnapshotNow() async {
    final dir = _dir;
    if (dir == null) throw StateError('Snapshot directory unavailable');

    final now = DateTime.now();
    final path = '${dir.path}/$_fileNamePrefix${_dateKey(now)}.json';

    final json = const JsonEncoder.withIndent('  ').convert(_backupService.buildBackupMap());
    await File(path).writeAsString(json);

    await _settingsRepository.setLastSnapshotDate(_dateKey(now));
    await pruneOldSnapshots();

    debugPrint('[Snapshot] Wrote $path');
    return path;
  }

  /// All snapshots on disk, newest first.
  List<SnapshotInfo> listSnapshots() {
    final dir = _dir;
    if (dir == null) return const [];

    try {
      final snapshots = <SnapshotInfo>[];
      for (final file in dir.listSync().whereType<File>()) {
        final date = _dateFromFileName(file.uri.pathSegments.last);
        if (date == null) continue;
        snapshots.add(SnapshotInfo(path: file.path, date: date, sizeBytes: file.lengthSync()));
      }
      return snapshots..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      debugPrint('[Snapshot] Failed to list snapshots: $e');
      return const [];
    }
  }

  /// The most recent snapshot, or null if none exist.
  SnapshotInfo? latestSnapshot() {
    final all = listSnapshots();
    return all.isEmpty ? null : all.first;
  }

  /// Read and decode a snapshot file.
  Future<Map<String, dynamic>?> readSnapshot(String path) async {
    try {
      final decoded = jsonDecode(await File(path).readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('[Snapshot] Failed to read $path: $e');
      return null;
    }
  }

  /// Delete snapshots outside the retention window.
  ///
  /// Keeps every snapshot within the configured number of days, plus the
  /// first-of-month snapshots for the last [_monthlyRetentionMonths].
  Future<void> pruneOldSnapshots() async {
    final dir = _dir;
    if (dir == null) return;

    final retentionDays = _settingsRepository.getSnapshotRetentionDays();
    final now = DateTime.now();
    final dailyCutoff = DateTime(now.year, now.month, now.day).subtract(Duration(days: retentionDays));
    final monthlyCutoff = DateTime(now.year, now.month - _monthlyRetentionMonths);

    for (final snapshot in listSnapshots()) {
      if (!snapshot.date.isBefore(dailyCutoff)) continue;
      if (snapshot.date.day == 1 && !snapshot.date.isBefore(monthlyCutoff)) continue;

      try {
        await File(snapshot.path).delete();
        debugPrint('[Snapshot] Pruned ${snapshot.path}');
      } catch (e) {
        debugPrint('[Snapshot] Failed to prune ${snapshot.path}: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  bool _isDue() {
    final freq = frequency;
    if (freq == SnapshotFrequency.off) return false;
    if (freq == SnapshotFrequency.launch) return true;

    final last = _settingsRepository.getLastSnapshotDate();
    if (last.isEmpty) return true;

    final lastDate = DateTime.tryParse(last);
    if (lastDate == null) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final elapsed = today.difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays;

    return switch (freq) {
      SnapshotFrequency.daily => elapsed >= 1,
      SnapshotFrequency.weekly => elapsed >= 7,
      _ => false,
    };
  }

  static String _dateKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime? _dateFromFileName(String name) {
    final match = RegExp('^$_fileNamePrefix' r'(\d{4})-(\d{2})-(\d{2})\.json$').firstMatch(name);
    if (match == null) return null;
    return DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
  }
}

/// Translation keys for the frequency dropdown in settings.
extension SnapshotFrequencyLabel on SnapshotFrequency {
  String get translationKey => switch (this) {
    SnapshotFrequency.off => 'settings.snapshot_freq_off',
    SnapshotFrequency.launch => 'settings.snapshot_freq_launch',
    SnapshotFrequency.daily => 'settings.snapshot_freq_daily',
    SnapshotFrequency.weekly => 'settings.snapshot_freq_weekly',
  };
}
