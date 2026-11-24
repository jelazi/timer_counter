import 'package:flutter_test/flutter_test.dart';
import 'package:timer_counter/app/tray_title.dart';
import 'package:timer_counter/data/models/tray_display_settings.dart';

void main() {
  const defaults = TrayDisplaySettings();
  const everything = TrayDisplaySettings(titlePomodoroCountdown: true, titlePomodoroRound: true);
  const allOff = TrayDisplaySettings(titlePomodoroIcon: false, titleTaskName: false, titleTimerElapsed: false, titleTodayTotal: false);

  TrayPomodoroInfo pomodoro({bool isWork = true, bool isPaused = false, bool isAwaitingStart = false}) =>
      TrayPomodoroInfo(isWork: isWork, isPaused: isPaused, isAwaitingStart: isAwaitingStart, countdown: '18:42', round: 2, rounds: 4, phaseLabel: 'Práce');

  group('defaults without a pomodoro keep the title the app always showed', () {
    test('a running timer', () {
      expect(TrayTitle.build(display: defaults, timersLoaded: true, taskName: 'Úkol', elapsed: '00:42', todayTotal: '03:15'), 'Úkol 00:42 | 03:15');
    });

    test('no running timer', () {
      expect(TrayTitle.build(display: defaults, timersLoaded: true, todayTotal: '03:15'), '0:00 | 03:15');
    });

    test('timers not loaded yet', () {
      expect(TrayTitle.build(display: defaults, timersLoaded: false), '0:00');
    });
  });

  test('by default a running pomodoro is only an icon in front', () {
    expect(TrayTitle.build(display: defaults, timersLoaded: true, pomodoro: pomodoro(), taskName: 'Úkol', elapsed: '00:42', todayTotal: '03:15'), '🍅 · Úkol 00:42 | 03:15');
    expect(TrayTitle.build(display: defaults, timersLoaded: true, pomodoro: pomodoro(isWork: false), todayTotal: '03:15'), '☕ · 0:00 | 03:15');
  });

  test('countdown and round when switched on, with paused and waiting markers', () {
    expect(TrayTitle.build(display: everything, timersLoaded: true, pomodoro: pomodoro(), todayTotal: '03:15'), '🍅 18:42 2/4 · 0:00 | 03:15');
    expect(TrayTitle.build(display: everything, timersLoaded: true, pomodoro: pomodoro(isPaused: true), todayTotal: '03:15'), '🍅 18:42 2/4 ⏸ · 0:00 | 03:15');
    expect(TrayTitle.build(display: everything, timersLoaded: true, pomodoro: pomodoro(isAwaitingStart: true), todayTotal: '03:15'), '🍅 2/4 ▶ · 0:00 | 03:15');
  });

  test('each part can be switched off on its own', () {
    expect(TrayTitle.build(display: defaults.copyWith(titleTaskName: false), timersLoaded: true, taskName: 'Úkol', elapsed: '00:42', todayTotal: '03:15'), '00:42 | 03:15');
    expect(TrayTitle.build(display: defaults.copyWith(titleTodayTotal: false), timersLoaded: true, taskName: 'Úkol', elapsed: '00:42', todayTotal: '03:15'), 'Úkol 00:42');
    expect(TrayTitle.build(display: allOff.copyWith(titlePomodoroCountdown: true), timersLoaded: true, pomodoro: pomodoro(), todayTotal: '03:15'), '18:42');
  });

  test('with every part off the title is empty and only the app icon remains', () {
    expect(TrayTitle.build(display: allOff, timersLoaded: true, pomodoro: pomodoro(isPaused: true), taskName: 'Úkol', elapsed: '00:42', todayTotal: '03:15'), '');
  });

  test('the pomodoro and the timer come apart for the macOS menu bar, where the app icon sits between them', () {
    expect(
      TrayTitle.parts(display: everything, timersLoaded: true, pomodoro: pomodoro(), taskName: 'Úkol', elapsed: '00:42', todayTotal: '03:15'),
      (pomodoroPart: '🍅 18:42 2/4', timerPart: 'Úkol 00:42 | 03:15'),
    );
    expect(TrayTitle.parts(display: defaults, timersLoaded: true, todayTotal: '03:15'), (pomodoroPart: '', timerPart: '0:00 | 03:15'));
    expect(
      TrayTitle.parts(display: allOff.copyWith(titlePomodoroIcon: true, titleTodayTotal: true), timersLoaded: true, pomodoro: pomodoro(), todayTotal: '03:15'),
      (pomodoroPart: '🍅', timerPart: '03:15'),
    );
    expect(TrayTitle.build(display: allOff.copyWith(titlePomodoroIcon: true, titleTodayTotal: true), timersLoaded: true, pomodoro: pomodoro(), todayTotal: '03:15'), '🍅 | 03:15');
  });

  test('display settings survive a round trip and fall back to the defaults', () {
    const custom = TrayDisplaySettings(titlePomodoroCountdown: true, menuRecentTasks: false);
    expect(TrayDisplaySettings.fromJson(custom.toJson()), custom);
    expect(TrayDisplaySettings.fromJson({}), defaults);
  });
}
