import 'package:flutter_test/flutter_test.dart';
import 'package:timer_counter/core/services/pomodoro_engine.dart';
import 'package:timer_counter/data/models/pomodoro_session.dart';
import 'package:timer_counter/data/models/pomodoro_settings.dart';

void main() {
  final t0 = DateTime(2026, 11, 24, 9);
  DateTime at(int minutes, [int seconds = 0]) => t0.add(Duration(minutes: minutes, seconds: seconds));

  const settings = PomodoroSettings();
  const autoAll = PomodoroSettings(autoStartBreak: true, autoStartWork: true);

  PomodoroSession started([PomodoroSettings s = settings]) => PomodoroEngine.start(id: 's1', settings: s, now: t0, startDevice: 'macOS', startedWithTimer: true);

  PomodoroSession advanced(PomodoroSession s, DateTime now, [PomodoroSettings cfg = settings]) => PomodoroEngine.advance(s, cfg, now).session!;

  group('start', () {
    test('begins a running work phase with the configured length', () {
      final s = started();
      expect(s.phase, PomodoroPhase.work);
      expect(s.status, PomodoroStatus.running);
      expect(s.phaseDurationSeconds, 25 * 60);
      expect(s.remainingSeconds(at(10)), 15 * 60);
      expect(s.round(4), 1);
    });
  });

  group('advance', () {
    test('does nothing before the phase ends', () {
      final s = started();
      final r = PomodoroEngine.advance(s, settings, at(24, 59));
      expect(r.session, s);
      expect(r.transitions, isEmpty);
    });

    test('a finished work phase counts a pomodoro and auto-starts the short break', () {
      final r = PomodoroEngine.advance(started(), settings, at(26));
      final s = r.session!;
      expect(s.phase, PomodoroPhase.shortBreak);
      expect(s.status, PomodoroStatus.running);
      expect(s.phaseStartedAt, at(25));
      expect(s.completedPomodoros, 1);
      expect(s.workSeconds, 25 * 60);
      expect(s.remainingSeconds(at(26)), 4 * 60);
      expect(r.transitions, [PomodoroTransition(from: PomodoroPhase.work, to: PomodoroPhase.shortBreak, autoStarted: true, at: at(25))]);
    });

    test('after a break the work phase waits for confirmation by default', () {
      final s = advanced(started(), at(31));
      expect(s.phase, PomodoroPhase.work);
      expect(s.status, PomodoroStatus.awaitingStart);
      expect(s.phaseStartedAt, at(30));
      expect(s.breakSeconds, 5 * 60);
      expect(s.liveWaitingSeconds(at(31)), 60);
      expect(s.remainingSeconds(at(31)), 25 * 60);
    });

    test('with auto-start break off the break waits too', () {
      const cfg = PomodoroSettings(autoStartBreak: false);
      final s = advanced(started(cfg), at(26), cfg);
      expect(s.phase, PomodoroPhase.shortBreak);
      expect(s.status, PomodoroStatus.awaitingStart);
    });

    test('replays several phases and gives a long break after N pomodoros', () {
      // 4×25 work + 3×5 short = 115 min, then the 15 min long break.
      final r = PomodoroEngine.advance(started(autoAll), autoAll, at(116));
      final s = r.session!;
      expect(s.phase, PomodoroPhase.longBreak);
      expect(s.completedPomodoros, 4);
      expect(s.completedSinceLongBreak, 0);
      expect(s.round(4), 4);
      expect(r.transitions.map((t) => t.to), [
        PomodoroPhase.shortBreak,
        PomodoroPhase.work,
        PomodoroPhase.shortBreak,
        PomodoroPhase.work,
        PomodoroPhase.shortBreak,
        PomodoroPhase.work,
        PomodoroPhase.longBreak,
      ]);
      final afterLong = advanced(s, at(131), autoAll);
      expect(afterLong.phase, PomodoroPhase.work);
      expect(afterLong.round(4), 1);
    });

    test('ends a session idle past its phase end for more than a cycle', () {
      // Cycle = 4×25 + 3×5 + 15 = 130 min; the work phase ended at 25.
      final r = PomodoroEngine.advance(started(autoAll), autoAll, at(25 + 131));
      expect(r.session, isNull);
      final rec = r.endedRecord!;
      expect(rec.endReason, PomodoroEndReason.inactivity);
      expect(rec.endedAt, at(25));
      expect(rec.completedPomodoros, 1);
      expect(rec.workSeconds, 25 * 60);
      expect(rec.waitingSeconds, 0);
    });

    test('ends a session waiting for confirmation for more than a cycle', () {
      final waiting = advanced(started(), at(31));
      final r = PomodoroEngine.advance(waiting, settings, at(30 + 131));
      expect(r.session, isNull);
      expect(r.endedRecord!.endedAt, at(30));
      expect(r.endedRecord!.waitingSeconds, 0);
      expect(r.endedRecord!.breakSeconds, 5 * 60);
    });

    test('ends a session paused for more than a cycle at the moment it was paused', () {
      final paused = PomodoroEngine.pause(started(), at(10));
      expect(PomodoroEngine.advance(paused, settings, at(10 + 130)).session, isNotNull);
      final r = PomodoroEngine.advance(paused, settings, at(10 + 131));
      expect(r.session, isNull);
      expect(r.endedRecord!.endedAt, at(10));
      expect(r.endedRecord!.workSeconds, 10 * 60);
      expect(r.endedRecord!.completedPomodoros, 0);
    });

    test('settings edited mid-phase apply from the next phase', () {
      final s = started();
      const edited = PomodoroSettings(workMinutes: 50, shortBreakMinutes: 10);
      final stillRunning = PomodoroEngine.advance(s, edited, at(24)).session!;
      expect(stillRunning.phaseDurationSeconds, 25 * 60);
      final inBreak = PomodoroEngine.advance(s, edited, at(26)).session!;
      expect(inBreak.phase, PomodoroPhase.shortBreak);
      expect(inBreak.phaseDurationSeconds, 10 * 60);
    });
  });

  group('pause and resume', () {
    test('freeze the countdown and record the paused time', () {
      final paused = PomodoroEngine.pause(started(), at(10));
      expect(paused.status, PomodoroStatus.paused);
      expect(paused.remainingSeconds(at(20)), 15 * 60);
      expect(paused.livePausedSeconds(at(20)), 10 * 60);

      final resumed = PomodoroEngine.resume(paused, at(20));
      expect(resumed.status, PomodoroStatus.running);
      expect(resumed.pausedSeconds, 10 * 60);
      expect(resumed.remainingSeconds(at(20)), 15 * 60);
      expect(resumed.phaseEndsAt, at(35));

      final r = PomodoroEngine.advance(resumed, settings, at(36));
      expect(r.session!.phase, PomodoroPhase.shortBreak);
      expect(r.session!.phaseStartedAt, at(35));
      expect(r.session!.workSeconds, 25 * 60);
    });

    test('a paused session does not reach its phase end', () {
      final paused = PomodoroEngine.pause(started(), at(10));
      expect(PomodoroEngine.advance(paused, settings, at(60)).session, paused);
    });

    test('pause on a waiting session is a no-op', () {
      final waiting = advanced(started(), at(31));
      expect(PomodoroEngine.pause(waiting, at(32)), waiting);
    });
  });

  group('skip', () {
    test('skipped work keeps its time but is not a pomodoro', () {
      final s = PomodoroEngine.skip(started(), settings, at(10));
      expect(s.phase, PomodoroPhase.shortBreak);
      expect(s.status, PomodoroStatus.running);
      expect(s.phaseStartedAt, at(10));
      expect(s.workSeconds, 10 * 60);
      expect(s.completedPomodoros, 0);
      expect(s.completedSinceLongBreak, 0);
    });

    test('skipped break counts only its elapsed time and starts work at once', () {
      final inBreak = advanced(started(), at(27));
      final s = PomodoroEngine.skip(inBreak, settings, at(27));
      expect(s.phase, PomodoroPhase.work);
      expect(s.status, PomodoroStatus.running);
      expect(s.breakSeconds, 2 * 60);
      expect(s.round(4), 2);
    });

    test('skipping while paused closes the pause', () {
      final paused = PomodoroEngine.pause(started(), at(10));
      final s = PomodoroEngine.skip(paused, settings, at(15));
      expect(s.workSeconds, 10 * 60);
      expect(s.pausedSeconds, 5 * 60);
      expect(s.pausedAt, isNull);
    });

    test('skipped work does not trigger an early long break', () {
      var s = started(autoAll);
      s = advanced(s, at(31), autoAll); // 1 done, now work round 2
      s = PomodoroEngine.skip(s, autoAll, at(31));
      expect(s.phase, PomodoroPhase.shortBreak);
      expect(s.completedSinceLongBreak, 1);
    });
  });

  group('startPendingPhase', () {
    test('records the wait and uses the current settings', () {
      final waiting = advanced(started(), at(31));
      const edited = PomodoroSettings(workMinutes: 40);
      final s = PomodoroEngine.startPendingPhase(waiting, edited, at(33));
      expect(s.status, PomodoroStatus.running);
      expect(s.waitingSeconds, 3 * 60);
      expect(s.phaseStartedAt, at(33));
      expect(s.phaseDurationSeconds, 40 * 60);
    });
  });

  group('stop', () {
    test('summarises work, breaks, pause and wait', () {
      var s = started();
      s = PomodoroEngine.pause(s, at(5));
      s = PomodoroEngine.resume(s, at(7));
      s = advanced(s, at(40)); // work ended at 27, break ended at 32, waiting since 32
      final rec = PomodoroEngine.stop(s, at(40));
      expect(rec.id, 's1');
      expect(rec.endReason, PomodoroEndReason.manual);
      expect(rec.startedAt, t0);
      expect(rec.endedAt, at(40));
      expect(rec.completedPomodoros, 1);
      expect(rec.workSeconds, 25 * 60);
      expect(rec.breakSeconds, 5 * 60);
      expect(rec.pausedSeconds, 2 * 60);
      expect(rec.waitingSeconds, 8 * 60);
      expect(rec.workSeconds + rec.breakSeconds + rec.pausedSeconds + rec.waitingSeconds, s.totalSeconds(at(40)));
      expect(rec.startedWithTimer, isTrue);
      expect(rec.startDevice, 'macOS');
    });

    test('an unfinished work phase counts its time but no pomodoro', () {
      final rec = PomodoroEngine.stop(started(), at(12));
      expect(rec.workSeconds, 12 * 60);
      expect(rec.completedPomodoros, 0);
    });
  });

  group('json', () {
    test('session and record survive a round trip', () {
      final s = PomodoroEngine.pause(advanced(started(), at(26)), at(27, 30));
      expect(PomodoroSession.fromJson(s.toJson()), s);
      final rec = PomodoroEngine.stop(s, at(29));
      expect(PomodoroSessionRecord.fromJson(rec.toJson()), rec);
    });

    test('settings survive a round trip and clamp bad values', () {
      final s = const PomodoroSettings(workMinutes: 50, autoStartWork: true).copyWith(updatedAt: t0);
      expect(PomodoroSettings.fromJson(s.toJson()), s);
      final bad = PomodoroSettings.fromJson({'workMinutes': 0, 'roundsBeforeLongBreak': 99, 'autoStartBreak': 'nope'});
      expect(bad.workMinutes, PomodoroSettings.minMinutes);
      expect(bad.roundsBeforeLongBreak, PomodoroSettings.maxRounds);
      expect(bad.autoStartBreak, isFalse);
      expect(PomodoroSettings.fromJson({}), const PomodoroSettings());
    });
  });
}
