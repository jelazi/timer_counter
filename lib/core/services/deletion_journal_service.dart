import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/platform_utils.dart';

/// What caused a record to be deleted.
enum DeleteSource {
  /// The user deleted the record directly in the UI.
  userAction,

  /// Deleted as a side effect of deleting its parent (project → tasks → entries).
  cascade,

  /// A PocketBase real-time `delete` event removed it.
  syncRealtime,

  /// `downloadAll()` reconciliation removed it because it was absent remotely.
  syncReconcile,

  /// A bulk wipe (backup restore, "delete all data", sign-out with clear).
  bulkClear;

  static DeleteSource parse(String? value) => DeleteSource.values.firstWhere((s) => s.name == value, orElse: () => DeleteSource.userAction);
}

/// One journalled deletion, reconstructable back into a model.
@immutable
class JournalEntry {
  final DateTime timestamp;
  final DeleteSource source;

  /// Logical collection name: `time_entries`, `projects`, `tasks`, …
  final String collection;
  final String itemId;

  /// The full record as it existed immediately before deletion.
  final Map<String, dynamic> payload;

  const JournalEntry({required this.timestamp, required this.source, required this.collection, required this.itemId, required this.payload});

  Map<String, dynamic> toJson() => {
    'ts': timestamp.toIso8601String(),
    'source': source.name,
    'collection': collection,
    'item_id': itemId,
    'payload': payload,
  };

  static JournalEntry? tryParse(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      return JournalEntry(
        timestamp: DateTime.parse(json['ts'] as String),
        source: DeleteSource.parse(json['source'] as String?),
        collection: json['collection'] as String? ?? '',
        itemId: json['item_id'] as String? ?? '',
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    } catch (_) {
      return null;
    }
  }
}

/// Append-only forensic log of every deleted record.
///
/// Each line is a self-contained JSON object holding the record's full payload,
/// so anything deleted can be reconstructed even if it never made it into a
/// snapshot. Files are rotated monthly: `deletions-YYYY-MM.jsonl`.
///
/// Writes must never break the delete they are logging — every failure here is
/// swallowed and reported via [debugPrint].
class DeletionJournalService {
  static const int _retentionMonths = 6;

  Directory? _dir;

  /// Attributed to every deletion recorded until it is set back.
  ///
  /// Callers that delete on behalf of something other than the user (the sync
  /// service, cascades, bulk wipes) wrap their work in [withSource] rather than
  /// threading a source argument through every repository call.
  DeleteSource _currentSource = DeleteSource.userAction;

  DeleteSource get currentSource => _currentSource;

  Future<void> init() async {
    if (PlatformUtils.isWeb) return;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/journal');
      if (!await dir.exists()) await dir.create(recursive: true);
      _dir = dir;
      await _pruneOldFiles();
    } catch (e) {
      debugPrint('[DeletionJournal] Init failed: $e');
    }
  }

  /// Run [body] with every deletion inside it attributed to [source].
  Future<T> withSource<T>(DeleteSource source, Future<T> Function() body) async {
    final previous = _currentSource;
    _currentSource = source;
    try {
      return await body();
    } finally {
      _currentSource = previous;
    }
  }

  /// Append a deletion to the journal. Fire-and-forget: callers do not await it
  /// and it never throws.
  void record(String collection, String itemId, Map<String, dynamic> payload, {DeleteSource? source}) {
    final dir = _dir;
    if (dir == null) return;

    final entry = JournalEntry(timestamp: DateTime.now(), source: source ?? _currentSource, collection: collection, itemId: itemId, payload: payload);

    try {
      final file = File('${dir.path}/${_fileNameFor(entry.timestamp)}');
      file.writeAsStringSync('${jsonEncode(entry.toJson())}\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('[DeletionJournal] Failed to record $collection/$itemId: $e');
    }
  }

  /// Read journalled deletions, newest first.
  Future<List<JournalEntry>> readEntries({int limit = 500}) async {
    final dir = _dir;
    if (dir == null) return const [];

    try {
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jsonl')).toList()
        ..sort((a, b) => b.path.compareTo(a.path)); // newest month first

      final entries = <JournalEntry>[];
      for (final file in files) {
        final lines = await file.readAsLines();
        for (final line in lines.reversed) {
          if (line.trim().isEmpty) continue;
          final entry = JournalEntry.tryParse(line);
          if (entry != null) entries.add(entry);
          if (entries.length >= limit) return entries;
        }
      }
      return entries;
    } catch (e) {
      debugPrint('[DeletionJournal] Failed to read journal: $e');
      return const [];
    }
  }

  /// Absolute path of the journal directory, for "open folder" in the UI.
  String? get directoryPath => _dir?.path;

  String _fileNameFor(DateTime date) => 'deletions-${date.year}-${date.month.toString().padLeft(2, '0')}.jsonl';

  Future<void> _pruneOldFiles() async {
    final dir = _dir;
    if (dir == null) return;

    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month - _retentionMonths);

    for (final file in dir.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      final match = RegExp(r'^deletions-(\d{4})-(\d{2})\.jsonl$').firstMatch(name);
      if (match == null) continue;

      final fileMonth = DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!));
      if (fileMonth.isBefore(cutoff)) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('[DeletionJournal] Failed to prune $name: $e');
        }
      }
    }
  }
}
