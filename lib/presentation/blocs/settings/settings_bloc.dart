import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository _settingsRepository;

  SettingsBloc({required SettingsRepository settingsRepository}) : _settingsRepository = settingsRepository, super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<ChangeThemeMode>(_onChangeThemeMode);
    on<ChangeLanguage>(_onChangeLanguage);
    on<ChangeTimeFormat>(_onChangeTimeFormat);
    on<ChangeCurrency>(_onChangeCurrency);
    on<ChangeDailyWorkingHours>(_onChangeDailyWorkingHours);
    on<ChangeWeeklyWorkingDays>(_onChangeWeeklyWorkingDays);
    on<ToggleSimultaneousTimers>(_onToggleSimultaneousTimers);
    on<ToggleShowSeconds>(_onToggleShowSeconds);
    on<ToggleRoundTime>(_onToggleRoundTime);
    on<ChangeRoundToMinutes>(_onChangeRoundToMinutes);
    on<ToggleLaunchAtStartup>(_onToggleLaunchAtStartup);
    on<ToggleMinimizeToTray>(_onToggleMinimizeToTray);
    on<ToggleRemindStart>(_onToggleRemindStart);
    on<ToggleRemindStop>(_onToggleRemindStop);
    on<ToggleRemindBreak>(_onToggleRemindBreak);
    on<ToggleAllowOverlapTimes>(_onToggleAllowOverlapTimes);
    on<ChangeWorkSchedule>(_onChangeWorkSchedule);
  }

  Map<int, ({String start, String end, bool enabled})> _loadWorkSchedule() {
    final schedule = <int, ({String start, String end, bool enabled})>{};
    for (int day = 1; day <= 7; day++) {
      schedule[day] = (
        start: _settingsRepository.getWorkScheduleStart(day),
        end: _settingsRepository.getWorkScheduleEnd(day),
        enabled: _settingsRepository.getWorkScheduleEnabled(day),
      );
    }
    return schedule;
  }

  void _onLoadSettings(LoadSettings event, Emitter<SettingsState> emit) {
    emit(
      SettingsState(
        themeMode: _settingsRepository.getThemeMode(),
        language: _settingsRepository.getLanguage(),
        timeFormat: _settingsRepository.getTimeFormat(),
        currency: _settingsRepository.getCurrency(),
        dailyWorkingHours: _settingsRepository.getDailyWorkingHours(),
        weeklyWorkingDays: _settingsRepository.getWeeklyWorkingDays(),
        simultaneousTimers: _settingsRepository.getSimultaneousTimers(),
        showSeconds: _settingsRepository.getShowSeconds(),
        roundTime: _settingsRepository.getRoundTime(),
        roundToMinutes: _settingsRepository.getRoundToMinutes(),
        launchAtStartup: _settingsRepository.getLaunchAtStartup(),
        minimizeToTray: _settingsRepository.getMinimizeToTray(),
        remindStart: _settingsRepository.getRemindStart(),
        remindStop: _settingsRepository.getRemindStop(),
        remindBreak: _settingsRepository.getRemindBreak(),
        allowOverlapTimes: _settingsRepository.getAllowOverlapTimes(),
        workSchedule: _loadWorkSchedule(),
      ),
    );
  }

  Future<void> _onChangeThemeMode(ChangeThemeMode event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setThemeMode(event.mode);
    emit(state.copyWith(themeMode: event.mode));
  }

  Future<void> _onChangeLanguage(ChangeLanguage event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setLanguage(event.language);
    emit(state.copyWith(language: event.language));
  }

  Future<void> _onChangeTimeFormat(ChangeTimeFormat event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setTimeFormat(event.format);
    emit(state.copyWith(timeFormat: event.format));
  }

  Future<void> _onChangeCurrency(ChangeCurrency event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setCurrency(event.currency);
    emit(state.copyWith(currency: event.currency));
  }

  Future<void> _onChangeDailyWorkingHours(ChangeDailyWorkingHours event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setDailyWorkingHours(event.hours);
    emit(state.copyWith(dailyWorkingHours: event.hours));
  }

  Future<void> _onChangeWeeklyWorkingDays(ChangeWeeklyWorkingDays event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setWeeklyWorkingDays(event.days);
    emit(state.copyWith(weeklyWorkingDays: event.days));
  }

  Future<void> _onToggleSimultaneousTimers(ToggleSimultaneousTimers event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setSimultaneousTimers(event.value);
    emit(state.copyWith(simultaneousTimers: event.value));
  }

  Future<void> _onToggleShowSeconds(ToggleShowSeconds event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setShowSeconds(event.value);
    emit(state.copyWith(showSeconds: event.value));
  }

  Future<void> _onToggleRoundTime(ToggleRoundTime event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setRoundTime(event.value);
    emit(state.copyWith(roundTime: event.value));
  }

  Future<void> _onChangeRoundToMinutes(ChangeRoundToMinutes event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setRoundToMinutes(event.minutes);
    emit(state.copyWith(roundToMinutes: event.minutes));
  }

  Future<void> _onToggleLaunchAtStartup(ToggleLaunchAtStartup event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setLaunchAtStartup(event.value);
    emit(state.copyWith(launchAtStartup: event.value));
  }

  Future<void> _onToggleMinimizeToTray(ToggleMinimizeToTray event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setMinimizeToTray(event.value);
    emit(state.copyWith(minimizeToTray: event.value));
  }

  Future<void> _onToggleRemindStart(ToggleRemindStart event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setRemindStart(event.value);
    emit(state.copyWith(remindStart: event.value));
  }

  Future<void> _onToggleRemindStop(ToggleRemindStop event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setRemindStop(event.value);
    emit(state.copyWith(remindStop: event.value));
  }

  Future<void> _onToggleRemindBreak(ToggleRemindBreak event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setRemindBreak(event.value);
    emit(state.copyWith(remindBreak: event.value));
  }

  Future<void> _onToggleAllowOverlapTimes(ToggleAllowOverlapTimes event, Emitter<SettingsState> emit) async {
    await _settingsRepository.setAllowOverlapTimes(event.value);
    emit(state.copyWith(allowOverlapTimes: event.value));
  }

  Future<void> _onChangeWorkSchedule(ChangeWorkSchedule event, Emitter<SettingsState> emit) async {
    if (event.start != null) {
      await _settingsRepository.setWorkScheduleStart(event.weekday, event.start!);
    }
    if (event.end != null) {
      await _settingsRepository.setWorkScheduleEnd(event.weekday, event.end!);
    }
    if (event.enabled != null) {
      await _settingsRepository.setWorkScheduleEnabled(event.weekday, event.enabled!);
    }
    emit(state.copyWith(workSchedule: _loadWorkSchedule()));
  }
}
