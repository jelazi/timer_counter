import 'dart:convert';

import 'package:flutter/foundation.dart';

enum PendingOp { upsert, delete }

@immutable
class ReconcilePlan {
  final Set<String> deleteLocally;

  final Set<String> upload;

  const ReconcilePlan({required this.deleteLocally, required this.upload});
}

/// A record missing from a download counts as deleted remotely only if the
/// server is known to have had it; otherwise it is local work not yet uploaded.
class SyncLedger {
  final Map<String, Set<String>> _confirmed;
  final Map<String, Map<String, PendingOp>> _pending;

  /// Bumped on every [markPending], so an older in-flight push cannot clear a
  /// newer pending change to the same record when it completes.
  final Map<String, int> _pendingVersions = {};

  SyncLedger({Map<String, Set<String>>? confirmed, Map<String, Map<String, PendingOp>>? pending}) : _confirmed = confirmed ?? {}, _pending = pending ?? {};

  bool isConfirmed(String collection, String id) => _confirmed[collection]?.contains(id) ?? false;

  void confirm(String collection, String id) => (_confirmed[collection] ??= {}).add(id);

  void unconfirm(String collection, String id) => _confirmed[collection]?.remove(id);

  void setConfirmed(String collection, Iterable<String> ids) => _confirmed[collection] = ids.toSet();

  PendingOp? pendingOp(String collection, String id) => _pending[collection]?[id];

  int markPending(String collection, String id, PendingOp op) {
    (_pending[collection] ??= {})[id] = op;
    final key = _versionKey(collection, id);
    final version = (_pendingVersions[key] ?? 0) + 1;
    _pendingVersions[key] = version;
    return version;
  }

  int pendingVersion(String collection, String id) => _pendingVersions[_versionKey(collection, id)] ?? 0;

  void clearPending(String collection, String id, {required int version}) {
    if (pendingVersion(collection, id) != version) return;
    final ops = _pending[collection];
    ops?.remove(id);
    if (ops != null && ops.isEmpty) _pending.remove(collection);
  }

  List<(String, String, PendingOp)> pendingEntries() => [
    for (final collection in _pending.entries)
      for (final op in collection.value.entries) (collection.key, op.key, op.value),
  ];

  int get pendingCount => _pending.values.fold(0, (sum, ops) => sum + ops.length);

  ReconcilePlan plan(String collection, {required Set<String> localIds, required Set<String> remoteIds}) {
    final deleteLocally = <String>{};
    final upload = <String>{};
    for (final id in localIds) {
      if (remoteIds.contains(id)) continue;
      final op = pendingOp(collection, id);
      if (op == null && isConfirmed(collection, id)) {
        deleteLocally.add(id);
      } else if (op != PendingOp.delete) {
        upload.add(id);
      }
    }
    return ReconcilePlan(deleteLocally: deleteLocally, upload: upload);
  }

  void clear() {
    _confirmed.clear();
    _pending.clear();
    _pendingVersions.clear();
  }

  String encode() => jsonEncode({
    'confirmed': {for (final e in _confirmed.entries) e.key: e.value.toList()},
    'pending': {
      for (final e in _pending.entries) e.key: {for (final op in e.value.entries) op.key: op.value.name},
    },
  });

  /// An empty ledger is the safe fallback: nothing local is treated as deleted remotely.
  static SyncLedger decode(String raw) {
    if (raw.isEmpty) return SyncLedger();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final confirmed = <String, Set<String>>{
        for (final e in (map['confirmed'] as Map<String, dynamic>? ?? const {}).entries) e.key: (e.value as List).map((id) => id.toString()).toSet(),
      };
      final pending = <String, Map<String, PendingOp>>{};
      for (final e in (map['pending'] as Map<String, dynamic>? ?? const {}).entries) {
        final ops = <String, PendingOp>{};
        for (final op in (e.value as Map<String, dynamic>).entries) {
          final parsed = PendingOp.values.asNameMap()[op.value];
          if (parsed != null) ops[op.key] = parsed;
        }
        if (ops.isNotEmpty) pending[e.key] = ops;
      }
      return SyncLedger(confirmed: confirmed, pending: pending);
    } catch (e) {
      debugPrint('[SyncLedger] Malformed ledger, starting empty: $e');
      return SyncLedger();
    }
  }

  static String _versionKey(String collection, String id) => '$collection/$id';
}
