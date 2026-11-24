import 'package:flutter_test/flutter_test.dart';
import 'package:timer_counter/core/services/pomodoro_engine.dart';
import 'package:timer_counter/core/services/pomodoro_state_merge.dart';
import 'package:timer_counter/data/models/pomodoro_session.dart';
import 'package:timer_counter/data/models/pomodoro_settings.dart';

void main() {
  final t0 = DateTime(2026, 11, 24, 9);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));
  const settings = PomodoroSettings();

  PomodoroSession started(String id, int minute) => PomodoroEngine.start(id: id, settings: settings, now: at(minute));
  PomodoroLiveState live(PomodoroSession s, [List<String> ended = const []]) => PomodoroLiveState(session: s, endedSessionIds: ended, updatedAt: s.updatedAt);
  PomodoroLiveState none(DateTime when, [List<String> ended = const []]) => PomodoroLiveState(endedSessionIds: ended, updatedAt: when);

  void expectSymmetric(PomodoroLiveState a, PomodoroLiveState b, PomodoroLiveState expected) {
    expect(PomodoroStateMerge.merge(a, b).state, expected);
    expect(PomodoroStateMerge.merge(b, a).state, expected);
  }

  test('the newer change to the same session wins', () {
    final s = started('x', 0);
    final paused = PomodoroEngine.pause(s, at(5));
    expectSymmetric(live(s), live(paused), live(paused));
  });

  test('the side that ended a session beats a stale device still running it, even with an older timestamp', () {
    final s = started('x', 0);
    final ended = none(at(10), ['x']);
    final staleSkip = live(PomodoroEngine.skip(s, settings, at(15)), ['older']);
    expectSymmetric(ended, staleSkip, none(at(10), ['x', 'older']));
  });

  test('an empty state that never knew the session does not end it', () {
    final s = live(started('x', 0));
    expectSymmetric(PomodoroLiveState.empty, s, s);
    final otherEnded = none(at(30), ['y']);
    expectSymmetric(otherEnded, s, PomodoroLiveState(session: s.session, endedSessionIds: const ['y'], updatedAt: s.updatedAt));
  });

  test('two sessions started apart: the later one wins and the earlier one is superseded', () {
    final early = live(started('a', 0));
    final late = live(started('b', 10));
    for (final r in [PomodoroStateMerge.merge(early, late), PomodoroStateMerge.merge(late, early)]) {
      expect(r.state.session!.id, 'b');
      expect(r.state.endedSessionIds, ['a']);
      expect(r.superseded.single.session.id, 'a');
      expect(r.superseded.single.endedAt, at(10));
    }
  });

  test('a device that replaced a session keeps its new one against the old one', () {
    final replaced = live(started('b', 10), ['a']);
    final stale = live(PomodoroEngine.pause(started('a', 0), at(12)));
    final r = PomodoroStateMerge.merge(stale, replaced);
    expect(r.state, replaced);
    expect(r.superseded, isEmpty);
    expect(PomodoroStateMerge.merge(replaced, stale).state, replaced);
  });

  test('identical timestamps still pick the same state on both sides', () {
    final a = none(at(5), ['x']);
    final b = none(at(5), ['y']);
    expect(PomodoroStateMerge.merge(a, b).state, PomodoroStateMerge.merge(b, a).state);
  });

  test('live state survives a json round trip', () {
    final s = live(PomodoroEngine.pause(started('x', 0), at(3)), ['old']);
    expect(PomodoroLiveState.fromJson(s.toJson()), s);
    expect(PomodoroLiveState.fromJson(none(at(1)).toJson()), none(at(1)));
  });

  test('the ended list keeps the newest ids only', () {
    var ids = <String>[];
    for (var i = 0; i < 30; i++) {
      ids = PomodoroLiveState.withEndedId(ids, 's$i');
    }
    expect(ids, hasLength(PomodoroLiveState.maxEndedSessionIds));
    expect(ids.first, 's29');
  });
}
