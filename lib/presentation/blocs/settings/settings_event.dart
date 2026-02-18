import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

class ChangeThemeMode extends SettingsEvent {
  final String mode;
  const ChangeThemeMode(this.mode);

  @override
  List<Object?> get props => [mode];
}

class ChangeLanguage extends SettingsEvent {
  final String language;
  const ChangeLanguage(this.language);

  @override
  List<Object?> get props => [language];
}

class ChangeTimeFormat extends SettingsEvent {
  final String format;
  const ChangeTimeFormat(this.format);

  @override
  List<Object?> get props => [format];
}

class ChangeCurrency extends SettingsEvent {
  final String currency;
  const ChangeCurrency(this.currency);

  @override
  List<Object?> get props => [currency];
}

class ChangeDailyWorkingHours extends SettingsEvent {
  final double hours;
  const ChangeDailyWorkingHours(this.hours);

  @override
  List<Object?> get props => [hours];
}

class ChangeWeeklyWorkingDays extends SettingsEvent {
  final int days;
  const ChangeWeeklyWorkingDays(this.days);

  @override
  List<Object?> get props => [days];
}

class ToggleSimultaneousTimers extends SettingsEvent {
  final bool value;
  const ToggleSimultaneousTimers(this.value);

  @override
  List<Object?> get props => [value];
}

class ToggleShowSeconds extends SettingsEvent {
  final bool value;
  const ToggleShowSeconds(this.value);

  @override
  List<Object?> get props => [value];
}

class ToggleRoundTime extends SettingsEvent {
  final bool value;
  const ToggleRoundTime(this.value);

  @override
  List<Object?> get props => [value];
}

class ChangeRoundToMinutes extends SettingsEvent {
  final int minutes;
  const ChangeRoundToMinutes(this.minutes);

  @override
  List<Object?> get props => [minutes];
}

class ToggleLaunchAtStartup extends SettingsEvent {
  final bool value;
  const ToggleLaunchAtStartup(this.value);

  @override
  List<Object?> get props => [value];
}

class ToggleMinimizeToTray extends SettingsEvent {
  final bool value;
  const ToggleMinimizeToTray(this.value);

  @override
  List<Object?> get props => [value];
}

class ToggleRemindStart extends SettingsEvent {
  final bool value;
  const ToggleRemindStart(this.value);

  @override
  List<Object?> get props => [value];
}

class ToggleRemindStop extends SettingsEvent {
  final bool value;
  const ToggleRemindStop(this.value);

  @override
  List<Object?> get props => [value];
}

class ToggleRemindBreak extends SettingsEvent {
  final bool value;
  const ToggleRemindBreak(this.value);

  @override
  List<Object?> get props => [value];
}

class ToggleAllowOverlapTimes extends SettingsEvent {
  final bool value;
  const ToggleAllowOverlapTimes(this.value);

  @override
  List<Object?> get props => [value];
}

class ChangeWorkSchedule extends SettingsEvent {
  final int weekday;
  final String? start;
  final String? end;
  final bool? enabled;
  const ChangeWorkSchedule({required this.weekday, this.start, this.end, this.enabled});

  @override
  List<Object?> get props => [weekday, start, end, enabled];
}
