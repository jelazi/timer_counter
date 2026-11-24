import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'pomodoro_session.dart';

/// Moments the pomodoro can mark with a sound.
enum PomodoroSoundEvent { workStart, workEnd, breakEnd, cycleDone, warning }

/// The bundled sounds (`assets/sounds/<id>.wav`, Android `res/raw/pomodoro_<id>.wav`).
class PomodoroSounds {
  const PomodoroSounds._();

  static const String none = 'none';
  static const String tick = 'tick';
  static const List<String> selectable = ['bell', 'chime', 'ding_dong', 'marimba', 'triple_beep', 'arpeggio', 'soft_gong'];

  static String sanitize(dynamic value, String fallback) {
    final id = value is String ? value : '';
    return id == none || selectable.contains(id) ? id : fallback;
  }
}

class PomodoroSettings extends Equatable {
  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int roundsBeforeLongBreak;
  final bool autoStartBreak;
  final bool autoStartWork;
  final bool warnWhenNoTimer;

  /// Minutes before a phase ends to sound the warning; 0 = off.
  final int warningMinutes;
  final String soundWorkStart;
  final String soundWorkEnd;
  final String soundBreakEnd;
  final String soundCycleDone;
  final String soundWarning;
  final double volume;
  final bool ticking;

  /// Null until edited; an unedited side loses to any edited one when devices disagree.
  final DateTime? updatedAt;

  const PomodoroSettings({
    this.workMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.roundsBeforeLongBreak = 4,
    this.autoStartBreak = true,
    this.autoStartWork = false,
    this.warnWhenNoTimer = true,
    this.warningMinutes = 1,
    this.soundWorkStart = 'chime',
    this.soundWorkEnd = 'bell',
    this.soundBreakEnd = 'ding_dong',
    this.soundCycleDone = 'arpeggio',
    this.soundWarning = 'marimba',
    this.volume = 0.8,
    this.ticking = false,
    this.updatedAt,
  });

  static const int minMinutes = 1;
  static const int maxMinutes = 180;
  static const int minRounds = 1;
  static const int maxRounds = 12;
  static const int maxWarningMinutes = 10;

  int durationSecondsOf(PomodoroPhase phase) => switch (phase) {
    PomodoroPhase.work => workMinutes * 60,
    PomodoroPhase.shortBreak => shortBreakMinutes * 60,
    PomodoroPhase.longBreak => longBreakMinutes * 60,
  };

  /// One full cycle: N work phases, N-1 short breaks and the long break.
  int get cycleSeconds => (roundsBeforeLongBreak * workMinutes + (roundsBeforeLongBreak - 1) * shortBreakMinutes + longBreakMinutes) * 60;

  String soundFor(PomodoroSoundEvent event) => switch (event) {
    PomodoroSoundEvent.workStart => soundWorkStart,
    PomodoroSoundEvent.workEnd => soundWorkEnd,
    PomodoroSoundEvent.breakEnd => soundBreakEnd,
    PomodoroSoundEvent.cycleDone => soundCycleDone,
    PomodoroSoundEvent.warning => soundWarning,
  };

  PomodoroSettings withSound(PomodoroSoundEvent event, String sound) => switch (event) {
    PomodoroSoundEvent.workStart => copyWith(soundWorkStart: sound),
    PomodoroSoundEvent.workEnd => copyWith(soundWorkEnd: sound),
    PomodoroSoundEvent.breakEnd => copyWith(soundBreakEnd: sound),
    PomodoroSoundEvent.cycleDone => copyWith(soundCycleDone: sound),
    PomodoroSoundEvent.warning => copyWith(soundWarning: sound),
  };

  PomodoroSettings copyWith({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? roundsBeforeLongBreak,
    bool? autoStartBreak,
    bool? autoStartWork,
    bool? warnWhenNoTimer,
    int? warningMinutes,
    String? soundWorkStart,
    String? soundWorkEnd,
    String? soundBreakEnd,
    String? soundCycleDone,
    String? soundWarning,
    double? volume,
    bool? ticking,
    DateTime? updatedAt,
  }) {
    return PomodoroSettings(
      workMinutes: workMinutes ?? this.workMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      roundsBeforeLongBreak: roundsBeforeLongBreak ?? this.roundsBeforeLongBreak,
      autoStartBreak: autoStartBreak ?? this.autoStartBreak,
      autoStartWork: autoStartWork ?? this.autoStartWork,
      warnWhenNoTimer: warnWhenNoTimer ?? this.warnWhenNoTimer,
      warningMinutes: warningMinutes ?? this.warningMinutes,
      soundWorkStart: soundWorkStart ?? this.soundWorkStart,
      soundWorkEnd: soundWorkEnd ?? this.soundWorkEnd,
      soundBreakEnd: soundBreakEnd ?? this.soundBreakEnd,
      soundCycleDone: soundCycleDone ?? this.soundCycleDone,
      soundWarning: soundWarning ?? this.soundWarning,
      volume: volume ?? this.volume,
      ticking: ticking ?? this.ticking,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'workMinutes': workMinutes,
    'shortBreakMinutes': shortBreakMinutes,
    'longBreakMinutes': longBreakMinutes,
    'roundsBeforeLongBreak': roundsBeforeLongBreak,
    'autoStartBreak': autoStartBreak,
    'autoStartWork': autoStartWork,
    'warnWhenNoTimer': warnWhenNoTimer,
    'warningMinutes': warningMinutes,
    'soundWorkStart': soundWorkStart,
    'soundWorkEnd': soundWorkEnd,
    'soundBreakEnd': soundBreakEnd,
    'soundCycleDone': soundCycleDone,
    'soundWarning': soundWarning,
    'volume': volume,
    'ticking': ticking,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  factory PomodoroSettings.fromJson(Map<String, dynamic> json) {
    const d = PomodoroSettings();
    int minutes(dynamic v, int fallback) => parseInt(v, fallback: fallback).clamp(minMinutes, maxMinutes);
    return PomodoroSettings(
      workMinutes: minutes(json['workMinutes'], d.workMinutes),
      shortBreakMinutes: minutes(json['shortBreakMinutes'], d.shortBreakMinutes),
      longBreakMinutes: minutes(json['longBreakMinutes'], d.longBreakMinutes),
      roundsBeforeLongBreak: parseInt(json['roundsBeforeLongBreak'], fallback: d.roundsBeforeLongBreak).clamp(minRounds, maxRounds),
      autoStartBreak: parseBool(json['autoStartBreak'], fallback: d.autoStartBreak),
      autoStartWork: parseBool(json['autoStartWork'], fallback: d.autoStartWork),
      warnWhenNoTimer: parseBool(json['warnWhenNoTimer'], fallback: d.warnWhenNoTimer),
      warningMinutes: parseInt(json['warningMinutes'], fallback: d.warningMinutes).clamp(0, maxWarningMinutes),
      soundWorkStart: PomodoroSounds.sanitize(json['soundWorkStart'], d.soundWorkStart),
      soundWorkEnd: PomodoroSounds.sanitize(json['soundWorkEnd'], d.soundWorkEnd),
      soundBreakEnd: PomodoroSounds.sanitize(json['soundBreakEnd'], d.soundBreakEnd),
      soundCycleDone: PomodoroSounds.sanitize(json['soundCycleDone'], d.soundCycleDone),
      soundWarning: PomodoroSounds.sanitize(json['soundWarning'], d.soundWarning),
      volume: parseDouble(json['volume'], fallback: d.volume).clamp(0.0, 1.0),
      ticking: parseBool(json['ticking'], fallback: d.ticking),
      updatedAt: parseDateOrNull(json['updatedAt'])?.toLocal(),
    );
  }

  @override
  List<Object?> get props => [
    workMinutes,
    shortBreakMinutes,
    longBreakMinutes,
    roundsBeforeLongBreak,
    autoStartBreak,
    autoStartWork,
    warnWhenNoTimer,
    warningMinutes,
    soundWorkStart,
    soundWorkEnd,
    soundBreakEnd,
    soundCycleDone,
    soundWarning,
    volume,
    ticking,
    updatedAt,
  ];
}
