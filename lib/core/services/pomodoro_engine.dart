import 'package:equatable/equatable.dart';

import '../../data/models/pomodoro_session.dart';
import '../../data/models/pomodoro_settings.dart';

/// A phase that ended on its own and the phase that followed it.
class PomodoroTransition extends Equatable {
  final PomodoroPhase from;
  final PomodoroPhase to;
  final bool autoStarted;
  final DateTime at;

  const PomodoroTransition({required this.from, required this.to, required this.autoStarted, required this.at});

  @override
  List<Object?> get props => [from, to, autoStarted, at];
}

class PomodoroAdvance {
  /// Null when the session ended by inactivity.
  final PomodoroSession? session;
  final List<PomodoroTransition> transitions;
  final PomodoroSessionRecord? endedRecord;

  const PomodoroAdvance({required this.session, this.transitions = const [], this.endedRecord});
}

/// Pure pomodoro rules. Manual actions expect a session already brought up to
/// date with [advance].
class PomodoroEngine {
  const PomodoroEngine._();

  static PomodoroSession start({required String id, required PomodoroSettings settings, required DateTime now, String startDevice = '', bool startedWithTimer = false}) {
    return PomodoroSession(
      id: id,
      startedAt: now,
      startDevice: startDevice,
      startedWithTimer: startedWithTimer,
      phase: PomodoroPhase.work,
      status: PomodoroStatus.running,
      phaseStartedAt: now,
      phaseDurationSeconds: settings.durationSecondsOf(PomodoroPhase.work),
      updatedAt: now,
    );
  }

  /// Replays every phase end up to [now]. A session idle (paused, waiting, or
  /// past its phase end) for longer than a whole cycle ends at the moment it
  /// went idle, so a forgotten session does not run up hours of fake time.
  static PomodoroAdvance advance(PomodoroSession session, PomodoroSettings settings, DateTime now) {
    var s = session;
    final transitions = <PomodoroTransition>[];
    final idleLimit = Duration(seconds: settings.cycleSeconds);

    while (true) {
      switch (s.status) {
        case PomodoroStatus.running:
          final end = s.phaseEndsAt;
          if (now.isBefore(end)) return PomodoroAdvance(session: s, transitions: transitions);
          if (now.difference(end) > idleLimit) {
            final closed = _completePhase(s, settings, end, forceWait: true);
            return PomodoroAdvance(
              session: null,
              transitions: transitions,
              endedRecord: stop(closed.session, end, reason: PomodoroEndReason.inactivity),
            );
          }
          final next = _completePhase(s, settings, end);
          transitions.add(next.transition);
          s = next.session;
        case PomodoroStatus.paused:
          final since = s.pausedAt ?? s.phaseStartedAt;
          if (now.difference(since) > idleLimit) {
            return PomodoroAdvance(
              session: null,
              transitions: transitions,
              endedRecord: stop(s, since, reason: PomodoroEndReason.inactivity),
            );
          }
          return PomodoroAdvance(session: s, transitions: transitions);
        case PomodoroStatus.awaitingStart:
          if (now.difference(s.phaseStartedAt) > idleLimit) {
            return PomodoroAdvance(
              session: null,
              transitions: transitions,
              endedRecord: stop(s, s.phaseStartedAt, reason: PomodoroEndReason.inactivity),
            );
          }
          return PomodoroAdvance(session: s, transitions: transitions);
      }
    }
  }

  static PomodoroSession pause(PomodoroSession s, DateTime now) {
    if (!s.isRunning) return s;
    return s.copyWith(status: PomodoroStatus.paused, pausedAt: () => now, seq: s.seq + 1, updatedAt: now);
  }

  static PomodoroSession resume(PomodoroSession s, DateTime now) {
    if (!s.isPaused || s.pausedAt == null) return s;
    final paused = _seconds(s.pausedAt!, now);
    return s.copyWith(
      status: PomodoroStatus.running,
      pausedAt: () => null,
      pausedSecondsInPhase: s.pausedSecondsInPhase + paused,
      pausedSeconds: s.pausedSeconds + paused,
      seq: s.seq + 1,
      updatedAt: now,
    );
  }

  /// Starts the phase that is waiting for confirmation, with the current settings.
  static PomodoroSession startPendingPhase(PomodoroSession s, PomodoroSettings settings, DateTime now) {
    if (!s.isAwaitingStart) return s;
    return s.copyWith(
      status: PomodoroStatus.running,
      waitingSeconds: s.waitingSeconds + _seconds(s.phaseStartedAt, now),
      phaseStartedAt: now,
      phaseDurationSeconds: settings.durationSecondsOf(s.phase),
      pausedSecondsInPhase: 0,
      pausedAt: () => null,
      seq: s.seq + 1,
      updatedAt: now,
    );
  }

  /// Ends the current phase early and starts the next one right away. A
  /// skipped work phase keeps its time but does not count as a pomodoro.
  static PomodoroSession skip(PomodoroSession s, PomodoroSettings settings, DateTime now) {
    if (s.isAwaitingStart) return s;
    final elapsed = s.phaseElapsedSeconds(now);
    final paused = s.isPaused && s.pausedAt != null ? _seconds(s.pausedAt!, now) : 0;
    final isWork = s.phase == PomodoroPhase.work;
    final next = isWork ? PomodoroPhase.shortBreak : PomodoroPhase.work;
    return s.copyWith(
      phase: next,
      status: PomodoroStatus.running,
      phaseStartedAt: now,
      phaseDurationSeconds: settings.durationSecondsOf(next),
      pausedSecondsInPhase: 0,
      pausedAt: () => null,
      workSeconds: s.workSeconds + (isWork ? elapsed : 0),
      breakSeconds: s.breakSeconds + (isWork ? 0 : elapsed),
      pausedSeconds: s.pausedSeconds + paused,
      seq: s.seq + 1,
      updatedAt: now,
    );
  }

  static PomodoroSessionRecord stop(PomodoroSession s, DateTime now, {PomodoroEndReason reason = PomodoroEndReason.manual}) {
    final elapsed = s.phaseElapsedSeconds(now);
    final isWork = s.phase == PomodoroPhase.work;
    final paused = s.isPaused && s.pausedAt != null ? _seconds(s.pausedAt!, now) : 0;
    final waiting = s.isAwaitingStart ? _seconds(s.phaseStartedAt, now) : 0;
    return PomodoroSessionRecord(
      id: s.id,
      startedAt: s.startedAt,
      endedAt: now,
      endReason: reason,
      completedPomodoros: s.completedPomodoros,
      workSeconds: s.workSeconds + (isWork ? elapsed : 0),
      breakSeconds: s.breakSeconds + (isWork ? 0 : elapsed),
      pausedSeconds: s.pausedSeconds + paused,
      waitingSeconds: s.waitingSeconds + waiting,
      startedWithTimer: s.startedWithTimer,
      startDevice: s.startDevice,
    );
  }

  static ({PomodoroSession session, PomodoroTransition transition}) _completePhase(PomodoroSession s, PomodoroSettings settings, DateTime end, {bool forceWait = false}) {
    final isWork = s.phase == PomodoroPhase.work;
    var completed = s.completedPomodoros;
    var sinceLong = s.completedSinceLongBreak;
    final PomodoroPhase next;
    final bool auto;
    if (isWork) {
      completed++;
      sinceLong++;
      next = sinceLong >= settings.roundsBeforeLongBreak ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak;
      if (next == PomodoroPhase.longBreak) sinceLong = 0;
      auto = settings.autoStartBreak;
    } else {
      next = PomodoroPhase.work;
      auto = settings.autoStartWork;
    }
    final started = auto && !forceWait;
    final session = s.copyWith(
      phase: next,
      status: started ? PomodoroStatus.running : PomodoroStatus.awaitingStart,
      phaseStartedAt: end,
      phaseDurationSeconds: settings.durationSecondsOf(next),
      pausedSecondsInPhase: 0,
      pausedAt: () => null,
      completedPomodoros: completed,
      completedSinceLongBreak: sinceLong,
      workSeconds: s.workSeconds + (isWork ? s.phaseDurationSeconds : 0),
      breakSeconds: s.breakSeconds + (isWork ? 0 : s.phaseDurationSeconds),
      seq: s.seq + 1,
      updatedAt: end,
    );
    return (session: session, transition: PomodoroTransition(from: s.phase, to: next, autoStarted: started, at: end));
  }

  static int _seconds(DateTime from, DateTime to) {
    final s = to.difference(from).inSeconds;
    return s < 0 ? 0 : s;
  }
}
