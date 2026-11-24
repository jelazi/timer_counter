import 'package:equatable/equatable.dart';

import '../../data/models/pomodoro_session.dart';
import '../../data/models/pomodoro_settings.dart';
import 'pomodoro_engine.dart';

/// Sounds and notifications of the pomodoro. The bloc decides when; an
/// implementation decides how on its platform.
abstract class PomodoroAlerts {
  /// Called once translations are loaded (notification texts use them).
  Future<void> init();

  /// Fires when the user tapped a notification of a phase waiting to start.
  Stream<void> get startPendingRequests;

  Future<void> requestPermission();

  Future<bool> permissionGranted();

  Future<void> noTimerRunning();

  Future<void> phaseEnded(PomodoroTransition transition, PomodoroSession next);

  Future<void> workStarted();

  Future<void> warning(PomodoroSession session, int minutesLeft);

  Future<void> tick();

  /// Replaces the notifications planned ahead (where the platform needs them to
  /// ring while the app is suspended) with those for [session].
  Future<void> reschedule(PomodoroSession? session);

  Future<void> preview(String soundId);
}

PomodoroSoundEvent soundEventForEnd(PomodoroPhase endingPhase) => switch (endingPhase) {
  PomodoroPhase.work => PomodoroSoundEvent.workEnd,
  PomodoroPhase.shortBreak => PomodoroSoundEvent.breakEnd,
  PomodoroPhase.longBreak => PomodoroSoundEvent.cycleDone,
};

enum PlannedAlertKind { phaseEnd, warning }

class PlannedPomodoroAlert extends Equatable {
  final PlannedAlertKind kind;
  final DateTime at;

  /// The phase that ends (or is about to end, for a warning).
  final PomodoroPhase phase;

  /// For [PlannedAlertKind.phaseEnd]: the phase that follows and whether it waits.
  final PomodoroPhase? nextPhase;
  final bool nextAwaiting;
  final int nextMinutes;
  final int minutesLeft;

  const PlannedPomodoroAlert({required this.kind, required this.at, required this.phase, this.nextPhase, this.nextAwaiting = false, this.nextMinutes = 0, this.minutesLeft = 0});

  PomodoroSoundEvent get soundEvent => kind == PlannedAlertKind.warning ? PomodoroSoundEvent.warning : soundEventForEnd(phase);

  @override
  List<Object?> get props => [kind, at, phase, nextPhase, nextAwaiting, nextMinutes, minutesLeft];
}

class PomodoroAlertPlan {
  const PomodoroAlertPlan._();

  /// The warnings and phase ends still ahead of [now], following automatic
  /// transitions until a phase waits for confirmation (or [maxPhases] ends).
  static List<PlannedPomodoroAlert> upcoming(PomodoroSession? session, PomodoroSettings settings, DateTime now, {int maxPhases = 8}) {
    final plan = <PlannedPomodoroAlert>[];
    var s = session;
    for (var i = 0; i < maxPhases && s != null && s.isRunning; i++) {
      final end = s.phaseEndsAt;
      final warningSeconds = settings.warningMinutes * 60;
      if (warningSeconds > 0 && s.phaseDurationSeconds > warningSeconds) {
        final warnAt = end.subtract(Duration(seconds: warningSeconds));
        if (warnAt.isAfter(now)) {
          plan.add(PlannedPomodoroAlert(kind: PlannedAlertKind.warning, at: warnAt, phase: s.phase, minutesLeft: settings.warningMinutes));
        }
      }
      final next = PomodoroEngine.advance(s, settings, end).session;
      if (next == null) break;
      if (end.isAfter(now)) {
        plan.add(
          PlannedPomodoroAlert(
            kind: PlannedAlertKind.phaseEnd,
            at: end,
            phase: s.phase,
            nextPhase: next.phase,
            nextAwaiting: next.isAwaitingStart,
            nextMinutes: next.phaseDurationSeconds ~/ 60,
          ),
        );
      }
      s = next;
    }
    return plan;
  }
}
