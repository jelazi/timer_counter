import 'package:equatable/equatable.dart';

import '../../../data/models/pomodoro_session.dart';
import '../../../data/models/pomodoro_settings.dart';

class PomodoroState extends Equatable {
  final PomodoroSettings settings;
  final PomodoroSession? session;

  /// The moment the countdown values are computed for.
  final DateTime now;

  /// Pomodoros completed today, finished sessions plus the running one.
  final int todayCompleted;
  final bool showOnTimeTracking;
  final bool mobileTab;

  /// Finished sessions, newest first.
  final List<PomodoroSessionRecord> history;
  final bool soundsOnDevice;
  final bool notificationsOnDevice;

  /// False when the system refuses notifications for the app (mobile).
  final bool notificationsPermitted;

  /// Set once when a start found a session already running (on another
  /// device); the UI asks whether to take it over or replace it.
  final PomodoroSession? startConflict;
  final String? errorMessage;

  const PomodoroState({
    required this.settings,
    required this.now,
    this.session,
    this.todayCompleted = 0,
    this.showOnTimeTracking = true,
    this.mobileTab = false,
    this.history = const [],
    this.soundsOnDevice = true,
    this.notificationsOnDevice = true,
    this.notificationsPermitted = true,
    this.startConflict,
    this.errorMessage,
  });

  bool get isActive => session != null;

  @override
  List<Object?> get props => [
    settings,
    session,
    now,
    todayCompleted,
    showOnTimeTracking,
    mobileTab,
    history,
    soundsOnDevice,
    notificationsOnDevice,
    notificationsPermitted,
    startConflict,
    errorMessage,
  ];
}
