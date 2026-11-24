import 'dart:convert';

import '../../data/models/pomodoro_session.dart';

/// A session that lost to another session running at the same time; it ends
/// when the winner started.
class SupersededPomodoro {
  final PomodoroSession session;
  final DateTime endedAt;

  const SupersededPomodoro(this.session, this.endedAt);
}

class PomodoroMergeResult {
  final PomodoroLiveState state;
  final List<SupersededPomodoro> superseded;

  const PomodoroMergeResult(this.state, [this.superseded = const []]);
}

/// Reconciles two devices' views of the shared pomodoro state. The result does
/// not depend on the argument order, so devices that exchange states settle on
/// the same one instead of overwriting each other.
class PomodoroStateMerge {
  const PomodoroStateMerge._();

  static PomodoroMergeResult merge(PomodoroLiveState a, PomodoroLiveState b) {
    final sa = a.session;
    final sb = b.session;

    if (sa != null && sb != null && sa.id != sb.id) {
      if (a.endedSessionIds.contains(sb.id) && !b.endedSessionIds.contains(sa.id)) return _keep(a, b);
      if (b.endedSessionIds.contains(sa.id) && !a.endedSessionIds.contains(sb.id)) return _keep(b, a);
      final aWins = _compareStarts(sa, sb) > 0;
      final winner = aWins ? a : b;
      final loser = aWins ? sb : sa;
      final endedAt = winner.session!.startedAt.isBefore(loser.startedAt) ? loser.startedAt : winner.session!.startedAt;
      return PomodoroMergeResult(
        PomodoroLiveState(
          session: winner.session,
          endedSessionIds: PomodoroLiveState.withEndedId(_union(winner.endedSessionIds, (aWins ? b : a).endedSessionIds), loser.id),
          updatedAt: winner.updatedAt,
        ),
        [SupersededPomodoro(loser, endedAt)],
      );
    }

    // An empty side beats a running session only if it is the side that ended it.
    if (sa != null && sb == null) return b.endedSessionIds.contains(sa.id) ? _keep(b, a) : _keep(a, b);
    if (sb != null && sa == null) return a.endedSessionIds.contains(sb.id) ? _keep(a, b) : _keep(b, a);

    return _compareNewer(a, b) >= 0 ? _keep(a, b) : _keep(b, a);
  }

  static PomodoroMergeResult _keep(PomodoroLiveState winner, PomodoroLiveState other) =>
      PomodoroMergeResult(PomodoroLiveState(session: winner.session, endedSessionIds: _union(winner.endedSessionIds, other.endedSessionIds), updatedAt: winner.updatedAt));

  /// Ended ids are only ever added, so knowledge of an ended session is never lost.
  static List<String> _union(List<String> first, List<String> second) {
    final ids = [...first, ...second.where((id) => !first.contains(id))];
    return ids.length > PomodoroLiveState.maxEndedSessionIds ? ids.sublist(0, PomodoroLiveState.maxEndedSessionIds) : ids;
  }

  static int _compareStarts(PomodoroSession a, PomodoroSession b) {
    final byTime = a.startedAt.compareTo(b.startedAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }

  static int _compareNewer(PomodoroLiveState a, PomodoroLiveState b) {
    final byTime = a.updatedAt.compareTo(b.updatedAt);
    if (byTime != 0) return byTime;
    final bySeq = (a.session?.seq ?? -1).compareTo(b.session?.seq ?? -1);
    if (bySeq != 0) return bySeq;
    return jsonEncode(a.toJson()).compareTo(jsonEncode(b.toJson()));
  }
}
