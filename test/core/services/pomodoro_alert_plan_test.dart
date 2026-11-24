import 'package:flutter_test/flutter_test.dart';
import 'package:timer_counter/core/services/pomodoro_alerts.dart';
import 'package:timer_counter/core/services/pomodoro_engine.dart';
import 'package:timer_counter/data/models/pomodoro_session.dart';
import 'package:timer_counter/data/models/pomodoro_settings.dart';

void main() {
  final t0 = DateTime(2026, 11, 24, 9);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));
  const settings = PomodoroSettings();

  PomodoroSession started([PomodoroSettings s = settings]) => PomodoroEngine.start(id: 's', settings: s, now: t0);

  test('a running work phase plans its warning and end, the break, and stops at the phase that waits', () {
    final plan = PomodoroAlertPlan.upcoming(started(), settings, t0);
    expect(plan, [
      PlannedPomodoroAlert(kind: PlannedAlertKind.warning, at: at(24), phase: PomodoroPhase.work, minutesLeft: 1),
      PlannedPomodoroAlert(kind: PlannedAlertKind.phaseEnd, at: at(25), phase: PomodoroPhase.work, nextPhase: PomodoroPhase.shortBreak, nextMinutes: 5),
      PlannedPomodoroAlert(kind: PlannedAlertKind.warning, at: at(29), phase: PomodoroPhase.shortBreak, minutesLeft: 1),
      PlannedPomodoroAlert(kind: PlannedAlertKind.phaseEnd, at: at(30), phase: PomodoroPhase.shortBreak, nextPhase: PomodoroPhase.work, nextAwaiting: true, nextMinutes: 25),
    ]);
    expect(plan.map((a) => a.soundEvent), [PomodoroSoundEvent.warning, PomodoroSoundEvent.workEnd, PomodoroSoundEvent.warning, PomodoroSoundEvent.breakEnd]);
  });

  test('with both auto-starts the plan follows the cycle up to the limit and marks the long break end', () {
    const auto = PomodoroSettings(autoStartWork: true, warningMinutes: 0);
    final plan = PomodoroAlertPlan.upcoming(started(auto), auto, t0);
    expect(plan, hasLength(8));
    expect(plan.every((a) => a.kind == PlannedAlertKind.phaseEnd), isTrue);
    expect(plan[6].nextPhase, PomodoroPhase.longBreak);
    expect(plan[7].soundEvent, PomodoroSoundEvent.cycleDone);
    expect(plan[7].at, at(130));
  });

  test('alerts already behind now are left out', () {
    final plan = PomodoroAlertPlan.upcoming(started(), settings, at(24));
    expect(plan.first.kind, PlannedAlertKind.phaseEnd);
    expect(plan.first.at, at(25));
  });

  test('a paused or waiting session plans nothing', () {
    expect(PomodoroAlertPlan.upcoming(PomodoroEngine.pause(started(), at(3)), settings, at(4)), isEmpty);
    final waiting = PomodoroEngine.advance(started(), settings, at(31)).session!;
    expect(waiting.isAwaitingStart, isTrue);
    expect(PomodoroAlertPlan.upcoming(waiting, settings, at(31)), isEmpty);
    expect(PomodoroAlertPlan.upcoming(null, settings, t0), isEmpty);
  });

  test('no warning for a phase not longer than the warning', () {
    const s = PomodoroSettings(shortBreakMinutes: 1);
    final plan = PomodoroAlertPlan.upcoming(started(s), s, t0);
    expect(plan.where((a) => a.phase == PomodoroPhase.shortBreak && a.kind == PlannedAlertKind.warning), isEmpty);
  });

  test('sound settings survive a round trip and unknown sounds fall back', () {
    final s = const PomodoroSettings(soundWorkEnd: 'soft_gong', soundWarning: PomodoroSounds.none, volume: 0.3, ticking: true, warningMinutes: 3);
    expect(PomodoroSettings.fromJson(s.toJson()), s);
    final bad = PomodoroSettings.fromJson({'soundWorkEnd': 'airhorn', 'volume': 7, 'warningMinutes': 99});
    expect(bad.soundWorkEnd, const PomodoroSettings().soundWorkEnd);
    expect(bad.volume, 1.0);
    expect(bad.warningMinutes, PomodoroSettings.maxWarningMinutes);
    expect(s.withSound(PomodoroSoundEvent.cycleDone, 'bell').soundFor(PomodoroSoundEvent.cycleDone), 'bell');
  });
}
