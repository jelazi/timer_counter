import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';

enum PomodoroPhase {
  work,
  shortBreak,
  longBreak;

  bool get isBreak => this != PomodoroPhase.work;
}

enum PomodoroStatus { running, paused, awaitingStart }

enum PomodoroEndReason { manual, inactivity, replaced }

T _enumByName<T extends Enum>(List<T> values, dynamic name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// The live pomodoro session. Everything is derived from timestamps, so any
/// device holding the same record computes the same phase and countdown.
class PomodoroSession extends Equatable {
  final String id;
  final DateTime startedAt;
  final String startDevice;
  final bool startedWithTimer;

  final PomodoroPhase phase;
  final PomodoroStatus status;

  /// Incremented on every transition and manual action.
  final int seq;

  /// When the phase started running; while [PomodoroStatus.awaitingStart], when the wait began.
  final DateTime phaseStartedAt;

  /// Copied from the settings when the phase started, so edits apply from the next phase.
  final int phaseDurationSeconds;
  final int pausedSecondsInPhase;
  final DateTime? pausedAt;

  final int completedPomodoros;
  final int completedSinceLongBreak;

  /// Totals of the closed segments; the live values add the open one.
  final int workSeconds;
  final int breakSeconds;
  final int pausedSeconds;
  final int waitingSeconds;

  final DateTime updatedAt;

  const PomodoroSession({
    required this.id,
    required this.startedAt,
    this.startDevice = '',
    this.startedWithTimer = false,
    required this.phase,
    required this.status,
    this.seq = 0,
    required this.phaseStartedAt,
    required this.phaseDurationSeconds,
    this.pausedSecondsInPhase = 0,
    this.pausedAt,
    this.completedPomodoros = 0,
    this.completedSinceLongBreak = 0,
    this.workSeconds = 0,
    this.breakSeconds = 0,
    this.pausedSeconds = 0,
    this.waitingSeconds = 0,
    required this.updatedAt,
  });

  bool get isRunning => status == PomodoroStatus.running;
  bool get isPaused => status == PomodoroStatus.paused;
  bool get isAwaitingStart => status == PomodoroStatus.awaitingStart;

  DateTime get phaseEndsAt => phaseStartedAt.add(Duration(seconds: phaseDurationSeconds + pausedSecondsInPhase));

  int phaseElapsedSeconds(DateTime now) {
    final DateTime until;
    switch (status) {
      case PomodoroStatus.awaitingStart:
        return 0;
      case PomodoroStatus.paused:
        until = pausedAt ?? now;
      case PomodoroStatus.running:
        until = now;
    }
    final elapsed = until.difference(phaseStartedAt).inSeconds - pausedSecondsInPhase;
    return elapsed.clamp(0, phaseDurationSeconds);
  }

  int remainingSeconds(DateTime now) => phaseDurationSeconds - phaseElapsedSeconds(now);

  double progress(DateTime now) => phaseDurationSeconds <= 0 ? 0 : phaseElapsedSeconds(now) / phaseDurationSeconds;

  int liveWorkSeconds(DateTime now) => workSeconds + (phase == PomodoroPhase.work ? phaseElapsedSeconds(now) : 0);

  int liveBreakSeconds(DateTime now) => breakSeconds + (phase.isBreak ? phaseElapsedSeconds(now) : 0);

  int livePausedSeconds(DateTime now) => pausedSeconds + (isPaused && pausedAt != null ? _nonNegative(now.difference(pausedAt!).inSeconds) : 0);

  int liveWaitingSeconds(DateTime now) => waitingSeconds + (isAwaitingStart ? _nonNegative(now.difference(phaseStartedAt).inSeconds) : 0);

  int totalSeconds(DateTime now) => _nonNegative(now.difference(startedAt).inSeconds);

  /// 1-based round within the current set of N pomodoros.
  int round(int roundsBeforeLongBreak) => switch (phase) {
    PomodoroPhase.work => (completedSinceLongBreak + 1).clamp(1, roundsBeforeLongBreak),
    PomodoroPhase.shortBreak => completedSinceLongBreak.clamp(1, roundsBeforeLongBreak),
    PomodoroPhase.longBreak => roundsBeforeLongBreak,
  };

  static int _nonNegative(int v) => v < 0 ? 0 : v;

  PomodoroSession copyWith({
    PomodoroPhase? phase,
    PomodoroStatus? status,
    int? seq,
    DateTime? phaseStartedAt,
    int? phaseDurationSeconds,
    int? pausedSecondsInPhase,
    DateTime? Function()? pausedAt,
    int? completedPomodoros,
    int? completedSinceLongBreak,
    int? workSeconds,
    int? breakSeconds,
    int? pausedSeconds,
    int? waitingSeconds,
    DateTime? updatedAt,
  }) {
    return PomodoroSession(
      id: id,
      startedAt: startedAt,
      startDevice: startDevice,
      startedWithTimer: startedWithTimer,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      seq: seq ?? this.seq,
      phaseStartedAt: phaseStartedAt ?? this.phaseStartedAt,
      phaseDurationSeconds: phaseDurationSeconds ?? this.phaseDurationSeconds,
      pausedSecondsInPhase: pausedSecondsInPhase ?? this.pausedSecondsInPhase,
      pausedAt: pausedAt != null ? pausedAt() : this.pausedAt,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      completedSinceLongBreak: completedSinceLongBreak ?? this.completedSinceLongBreak,
      workSeconds: workSeconds ?? this.workSeconds,
      breakSeconds: breakSeconds ?? this.breakSeconds,
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
      waitingSeconds: waitingSeconds ?? this.waitingSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'startDevice': startDevice,
    'startedWithTimer': startedWithTimer,
    'phase': phase.name,
    'status': status.name,
    'seq': seq,
    'phaseStartedAt': phaseStartedAt.toUtc().toIso8601String(),
    'phaseDurationSeconds': phaseDurationSeconds,
    'pausedSecondsInPhase': pausedSecondsInPhase,
    'pausedAt': pausedAt?.toUtc().toIso8601String(),
    'completedPomodoros': completedPomodoros,
    'completedSinceLongBreak': completedSinceLongBreak,
    'workSeconds': workSeconds,
    'breakSeconds': breakSeconds,
    'pausedSeconds': pausedSeconds,
    'waitingSeconds': waitingSeconds,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory PomodoroSession.fromJson(Map<String, dynamic> json) {
    return PomodoroSession(
      id: parseString(json['id']),
      startedAt: parseDate(json['startedAt']).toLocal(),
      startDevice: parseString(json['startDevice']),
      startedWithTimer: parseBool(json['startedWithTimer']),
      phase: _enumByName(PomodoroPhase.values, json['phase'], PomodoroPhase.work),
      status: _enumByName(PomodoroStatus.values, json['status'], PomodoroStatus.awaitingStart),
      seq: parseInt(json['seq']),
      phaseStartedAt: parseDate(json['phaseStartedAt']).toLocal(),
      phaseDurationSeconds: parseInt(json['phaseDurationSeconds']),
      pausedSecondsInPhase: parseInt(json['pausedSecondsInPhase']),
      pausedAt: parseDateOrNull(json['pausedAt'])?.toLocal(),
      completedPomodoros: parseInt(json['completedPomodoros']),
      completedSinceLongBreak: parseInt(json['completedSinceLongBreak']),
      workSeconds: parseInt(json['workSeconds']),
      breakSeconds: parseInt(json['breakSeconds']),
      pausedSeconds: parseInt(json['pausedSeconds']),
      waitingSeconds: parseInt(json['waitingSeconds']),
      updatedAt: parseDate(json['updatedAt']).toLocal(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    startedAt,
    startDevice,
    startedWithTimer,
    phase,
    status,
    seq,
    phaseStartedAt,
    phaseDurationSeconds,
    pausedSecondsInPhase,
    pausedAt,
    completedPomodoros,
    completedSinceLongBreak,
    workSeconds,
    breakSeconds,
    pausedSeconds,
    waitingSeconds,
    updatedAt,
  ];
}

/// A finished session as kept in the history.
class PomodoroSessionRecord extends Equatable {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final PomodoroEndReason endReason;
  final int completedPomodoros;
  final int workSeconds;
  final int breakSeconds;
  final int pausedSeconds;
  final int waitingSeconds;
  final bool startedWithTimer;
  final String startDevice;

  const PomodoroSessionRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.endReason,
    this.completedPomodoros = 0,
    this.workSeconds = 0,
    this.breakSeconds = 0,
    this.pausedSeconds = 0,
    this.waitingSeconds = 0,
    this.startedWithTimer = false,
    this.startDevice = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'endReason': endReason.name,
    'completedPomodoros': completedPomodoros,
    'workSeconds': workSeconds,
    'breakSeconds': breakSeconds,
    'pausedSeconds': pausedSeconds,
    'waitingSeconds': waitingSeconds,
    'startedWithTimer': startedWithTimer,
    'startDevice': startDevice,
  };

  factory PomodoroSessionRecord.fromJson(Map<String, dynamic> json) {
    return PomodoroSessionRecord(
      id: parseString(json['id']),
      startedAt: parseDate(json['startedAt']).toLocal(),
      endedAt: parseDate(json['endedAt']).toLocal(),
      endReason: _enumByName(PomodoroEndReason.values, json['endReason'], PomodoroEndReason.manual),
      completedPomodoros: parseInt(json['completedPomodoros']),
      workSeconds: parseInt(json['workSeconds']),
      breakSeconds: parseInt(json['breakSeconds']),
      pausedSeconds: parseInt(json['pausedSeconds']),
      waitingSeconds: parseInt(json['waitingSeconds']),
      startedWithTimer: parseBool(json['startedWithTimer']),
      startDevice: parseString(json['startDevice']),
    );
  }

  @override
  List<Object?> get props => [id, startedAt, endedAt, endReason, completedPomodoros, workSeconds, breakSeconds, pausedSeconds, waitingSeconds, startedWithTimer, startDevice];
}

/// What every device of the account shares: the session (if any) and the ids
/// of sessions already ended, so a stale device cannot bring one back.
class PomodoroLiveState extends Equatable {
  final PomodoroSession? session;
  final List<String> endedSessionIds;
  final DateTime updatedAt;

  const PomodoroLiveState({this.session, this.endedSessionIds = const [], required this.updatedAt});

  static final PomodoroLiveState empty = PomodoroLiveState(updatedAt: DateTime.fromMillisecondsSinceEpoch(0));

  static const int maxEndedSessionIds = 20;

  bool get isEmpty => session == null && endedSessionIds.isEmpty;

  PomodoroLiveState withSession(PomodoroSession session) => PomodoroLiveState(session: session, endedSessionIds: endedSessionIds, updatedAt: session.updatedAt);

  PomodoroLiveState ended(String sessionId, DateTime at) => PomodoroLiveState(endedSessionIds: withEndedId(endedSessionIds, sessionId), updatedAt: at);

  static List<String> withEndedId(List<String> ids, String id) {
    final next = [id, ...ids.where((e) => e != id)];
    return next.length > maxEndedSessionIds ? next.sublist(0, maxEndedSessionIds) : next;
  }

  Map<String, dynamic> toJson() => {'session': session?.toJson(), 'endedSessionIds': endedSessionIds, 'updatedAt': updatedAt.toUtc().toIso8601String()};

  factory PomodoroLiveState.fromJson(Map<String, dynamic> json) {
    final rawSession = json['session'];
    final rawIds = json['endedSessionIds'];
    return PomodoroLiveState(
      session: rawSession is Map ? PomodoroSession.fromJson(Map<String, dynamic>.from(rawSession)) : null,
      endedSessionIds: rawIds is List ? rawIds.map((e) => e.toString()).toList() : const [],
      updatedAt: parseDate(json['updatedAt']).toLocal(),
    );
  }

  @override
  List<Object?> get props => [session, endedSessionIds, updatedAt];
}
