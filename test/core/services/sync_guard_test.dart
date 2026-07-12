import 'package:flutter_test/flutter_test.dart';
import 'package:timer_counter/core/services/pocketbase_sync_service.dart';

/// The data-loss bug this guards against: a sync reconcile deletes local records
/// that the remote list did not mention, and a failed/short fetch is
/// indistinguishable from a genuine deletion.
void main() {
  group('SyncGuard.blocks', () {
    test('allows a reconcile that deletes nothing', () {
      expect(SyncGuard.blocks(deleteCount: 0, localCount: 100, remoteCount: 100), isFalse);
    });

    test('blocks an empty remote while local holds data — the failed-fetch signature', () {
      expect(SyncGuard.blocks(deleteCount: 500, localCount: 500, remoteCount: 0), isTrue);
    });

    test('allows an empty remote when local is also empty', () {
      expect(SyncGuard.blocks(deleteCount: 0, localCount: 0, remoteCount: 0), isFalse);
    });

    test('allows small deletions regardless of fraction', () {
      // Deleting 2 of 3 projects is 66 % but an entirely normal user action.
      expect(SyncGuard.blocks(deleteCount: 2, localCount: 3, remoteCount: 1), isFalse);
      expect(SyncGuard.blocks(deleteCount: 9, localCount: 10, remoteCount: 1), isFalse);
    });

    test('allows a large deletion that stays under the fraction threshold', () {
      // 20 of 100 = 20 %, below the 30 % limit.
      expect(SyncGuard.blocks(deleteCount: 20, localCount: 100, remoteCount: 80), isFalse);
    });

    test('blocks a large deletion above the fraction threshold', () {
      // 47 of 100 = 47 %, over the limit — the reported symptom.
      expect(SyncGuard.blocks(deleteCount: 47, localCount: 100, remoteCount: 53), isTrue);
    });

    test('boundary: exactly 30 % passes, just over blocks', () {
      expect(SyncGuard.blocks(deleteCount: 30, localCount: 100, remoteCount: 70), isFalse);
      expect(SyncGuard.blocks(deleteCount: 31, localCount: 100, remoteCount: 69), isTrue);
    });

    test('boundary: the absolute floor wins under 10 deletions', () {
      // 9 of 10 is 90 % but below the floor, so it is allowed.
      expect(SyncGuard.blocks(deleteCount: 9, localCount: 10, remoteCount: 1), isFalse);
      // 10 of 10 would be an empty remote, which is blocked by the first rule.
      expect(SyncGuard.blocks(deleteCount: 10, localCount: 10, remoteCount: 0), isTrue);
    });
  });
}
