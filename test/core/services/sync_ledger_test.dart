import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timer_counter/core/services/pocketbase_sync_service.dart';
import 'package:timer_counter/core/services/sync_ledger.dart';

void main() {
  const entries = 'time_entries';

  group('SyncLedger.plan', () {
    test('keeps and uploads records the server has never had', () {
      final ledger = SyncLedger()..setConfirmed(entries, {'a', 'b'});

      final plan = ledger.plan(entries, localIds: {'a', 'b', 'offline1', 'offline2'}, remoteIds: {'a', 'b'});

      expect(plan.deleteLocally, isEmpty);
      expect(plan.upload, {'offline1', 'offline2'});
    });

    test('deletes a record the server had and no longer has', () {
      final ledger = SyncLedger()..setConfirmed(entries, {'a', 'b'});

      final plan = ledger.plan(entries, localIds: {'a', 'b'}, remoteIds: {'a'});

      expect(plan.deleteLocally, {'b'});
      expect(plan.upload, isEmpty);
    });

    test('an unsent local edit wins over a remote deletion', () {
      final ledger = SyncLedger()..setConfirmed(entries, {'a'});
      ledger.markPending(entries, 'a', PendingOp.upsert);

      final plan = ledger.plan(entries, localIds: {'a'}, remoteIds: {});

      expect(plan.deleteLocally, isEmpty);
      expect(plan.upload, {'a'});
    });

    test('an empty ledger never deletes local records', () {
      final plan = SyncLedger().plan(entries, localIds: {'a', 'b'}, remoteIds: {});

      expect(plan.deleteLocally, isEmpty);
      expect(plan.upload, {'a', 'b'});
    });

    test('a week of entries recorded with an expired token survives the next sign-in', () {
      final synced = {for (var i = 0; i < 197; i++) 'synced$i'};
      final offline = {for (var i = 0; i < 42; i++) 'offline$i'};
      final ledger = SyncLedger()..setConfirmed(entries, synced);
      for (final id in offline) {
        ledger.markPending(entries, id, PendingOp.upsert);
      }

      final plan = ledger.plan(entries, localIds: {...synced, ...offline}, remoteIds: synced);

      expect(plan.deleteLocally, isEmpty);
      expect(plan.upload, offline);
    });
  });

  group('SyncLedger pending changes', () {
    test('an older push completing does not clear a newer pending change', () {
      final ledger = SyncLedger();
      final first = ledger.markPending(entries, 'a', PendingOp.upsert);
      ledger.markPending(entries, 'a', PendingOp.upsert);

      ledger.clearPending(entries, 'a', version: first);

      expect(ledger.pendingOp(entries, 'a'), PendingOp.upsert);
    });

    test('the latest push completing clears the pending change', () {
      final ledger = SyncLedger();
      ledger.markPending(entries, 'a', PendingOp.upsert);
      final latest = ledger.markPending(entries, 'a', PendingOp.delete);

      ledger.clearPending(entries, 'a', version: latest);

      expect(ledger.pendingOp(entries, 'a'), isNull);
      expect(ledger.pendingCount, 0);
    });
  });

  group('SyncLedger persistence', () {
    test('round-trips confirmed ids and pending changes', () {
      final ledger = SyncLedger()
        ..setConfirmed(entries, {'a', 'b'})
        ..setConfirmed('day_overrides', {'2026-10-02'});
      ledger.markPending(entries, 'c', PendingOp.upsert);
      ledger.markPending('projects', 'p', PendingOp.delete);

      final restored = SyncLedger.decode(ledger.encode());

      expect(restored.isConfirmed(entries, 'a'), isTrue);
      expect(restored.isConfirmed(entries, 'c'), isFalse);
      expect(restored.isConfirmed('day_overrides', '2026-10-02'), isTrue);
      expect(restored.pendingOp(entries, 'c'), PendingOp.upsert);
      expect(restored.pendingOp('projects', 'p'), PendingOp.delete);
    });

    test('malformed data yields an empty ledger', () {
      expect(SyncLedger.decode('not json').pendingCount, 0);
      expect(SyncLedger.decode('').isConfirmed(entries, 'a'), isFalse);
    });
  });

  group('PocketBaseSyncService.tokenExpiry', () {
    String jwt(Map<String, dynamic> payload) {
      String part(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
      return '${part({'alg': 'HS256'})}.${part(payload)}.signature';
    }

    test('reads the exp claim', () {
      expect(PocketBaseSyncService.tokenExpiry(jwt({'exp': 1760000000})), DateTime.fromMillisecondsSinceEpoch(1760000000 * 1000));
    });

    test('returns null for a token it cannot read', () {
      expect(PocketBaseSyncService.tokenExpiry(''), isNull);
      expect(PocketBaseSyncService.tokenExpiry('a.b.c'), isNull);
      expect(PocketBaseSyncService.tokenExpiry(jwt({'sub': 'x'})), isNull);
    });
  });
}
