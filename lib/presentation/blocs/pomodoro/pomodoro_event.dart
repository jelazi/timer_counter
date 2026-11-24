import 'package:equatable/equatable.dart';

import '../../../data/models/pomodoro_session.dart';
import '../../../data/models/pomodoro_settings.dart';

abstract class PomodoroEvent extends Equatable {
  const PomodoroEvent();

  @override
  List<Object?> get props => [];
}

class LoadPomodoro extends PomodoroEvent {
  const LoadPomodoro();
}

class StartPomodoro extends PomodoroEvent {
  /// Ends a session already running (on another device) and starts a new one.
  final bool replaceExisting;

  /// Started where no dialog can ask first (the tray): warn by notification instead.
  final bool notifyIfNoTimer;

  /// A project timer was started together with the pomodoro.
  final bool timerStarted;

  const StartPomodoro({this.replaceExisting = false, this.notifyIfNoTimer = false, this.timerStarted = false});

  @override
  List<Object?> get props => [replaceExisting, notifyIfNoTimer, timerStarted];
}

class PausePomodoro extends PomodoroEvent {
  const PausePomodoro();
}

class ResumePomodoro extends PomodoroEvent {
  const ResumePomodoro();
}

class SkipPomodoroPhase extends PomodoroEvent {
  const SkipPomodoroPhase();
}

/// Starts the phase that waits for confirmation.
class StartPendingPomodoroPhase extends PomodoroEvent {
  const StartPendingPomodoroPhase();
}

class StopPomodoro extends PomodoroEvent {
  const StopPomodoro();
}

class TickPomodoro extends PomodoroEvent {
  const TickPomodoro();
}

class UpdatePomodoroSettings extends PomodoroEvent {
  final PomodoroSettings settings;
  const UpdatePomodoroSettings(this.settings);

  @override
  List<Object?> get props => [settings];
}

class TogglePomodoroVisibility extends PomodoroEvent {
  final bool visible;
  const TogglePomodoroVisibility(this.visible);

  @override
  List<Object?> get props => [visible];
}

class TogglePomodoroDeviceSounds extends PomodoroEvent {
  final bool enabled;
  const TogglePomodoroDeviceSounds(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class TogglePomodoroDeviceNotifications extends PomodoroEvent {
  final bool enabled;
  const TogglePomodoroDeviceNotifications(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class RequestPomodoroPermission extends PomodoroEvent {
  const RequestPomodoroPermission();
}

class PreviewPomodoroSound extends PomodoroEvent {
  final String soundId;
  const PreviewPomodoroSound(this.soundId);

  @override
  List<Object?> get props => [soundId];
}

class DeletePomodoroRecord extends PomodoroEvent {
  final String id;
  const DeletePomodoroRecord(this.id);

  @override
  List<Object?> get props => [id];
}

class RestorePomodoroRecord extends PomodoroEvent {
  final PomodoroSessionRecord record;
  const RestorePomodoroRecord(this.record);

  @override
  List<Object?> get props => [record];
}

class TogglePomodoroMobileTab extends PomodoroEvent {
  final bool enabled;
  const TogglePomodoroMobileTab(this.enabled);

  @override
  List<Object?> get props => [enabled];
}
