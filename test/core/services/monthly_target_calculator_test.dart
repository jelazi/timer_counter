import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:timer_counter/core/services/monthly_target_calculator.dart';
import 'package:timer_counter/data/models/monthly_hours_target_model.dart';
import 'package:timer_counter/data/models/work_day_schedule.dart';
import 'package:timer_counter/data/repositories/settings_repository.dart';

/// Work contexts must stay invisible until someone opts into them: a target
/// with no settings of its own has to produce exactly the numbers it produced
/// before contexts existed.
void main() {
  late Directory tempDir;
  late SettingsRepository settings;
  late MonthlyTargetCalculator calculator;

  const contextId = 'ctx-medutech';
  const otherContextId = 'ctx-other';

  MonthlyHoursTargetModel target({String id = contextId, double hours = 160, List<String> projectIds = const ['p1']}) {
    return MonthlyHoursTargetModel(id: id, name: 'Medutech', targetHours: hours, projectIds: projectIds, createdAt: DateTime(2026, 1, 1));
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('timer_counter_settings_test');
    Hive.init(tempDir.path);
    settings = SettingsRepository();
    await settings.init();
    calculator = MonthlyTargetCalculator(settings);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// Every weekday a work day, so day counts do not depend on the calendar.
  Future<void> makeEveryDayAWorkDay() async {
    for (int weekday = 1; weekday <= 7; weekday++) {
      await settings.setWorkDaySchedule(weekday, const WorkDaySchedule(start: '08:00', end: '16:00', enabled: true));
    }
  }

  group('schedule inheritance', () {
    test('a context without its own schedule follows the global one', () async {
      await settings.setWorkScheduleEnabled(6, false);
      final saturday = DateTime(2026, 9, 5);

      expect(settings.isWorkDay(saturday), isFalse);
      expect(settings.isWorkDay(saturday, contextId: contextId), isFalse);
    });

    test('an own schedule only applies once it is switched on', () async {
      await settings.setWorkScheduleEnabled(6, false);
      await settings.setContextOwnDaySchedule(contextId, 6, const WorkDaySchedule(start: '09:00', end: '13:00', enabled: true));
      final saturday = DateTime(2026, 9, 5);

      expect(settings.isWorkDay(saturday, contextId: contextId), isFalse);

      await settings.setContextUsesOwnSchedule(contextId, true);

      expect(settings.isWorkDay(saturday, contextId: contextId), isTrue);
      expect(settings.getExpectedHoursForDate(saturday, contextId: contextId), 4);
      // The global answer and other contexts are untouched.
      expect(settings.isWorkDay(saturday), isFalse);
      expect(settings.isWorkDay(saturday, contextId: otherContextId), isFalse);
    });

    test('an own schedule defaults to a copy of the global one', () async {
      await settings.setWorkDaySchedule(1, const WorkDaySchedule(start: '07:30', end: '15:30', enabled: true));

      expect(settings.getContextOwnDaySchedule(contextId, 1), const WorkDaySchedule(start: '07:30', end: '15:30', enabled: true));
    });
  });

  group('day overrides', () {
    test('a global day off is inherited by every context', () async {
      await makeEveryDayAWorkDay();
      final christmas = DateTime(2026, 12, 24);
      await settings.setDayOverride(christmas, 'off');

      expect(settings.isWorkDay(christmas, contextId: contextId), isFalse);
    });

    test("a context's own override wins over the global one", () async {
      await makeEveryDayAWorkDay();
      final date = DateTime(2026, 12, 24);
      await settings.setDayOverride(date, 'off');
      await settings.setContextDayOverride(contextId, date, 'work');

      expect(settings.isWorkDay(date), isFalse);
      expect(settings.isWorkDay(date, contextId: contextId), isTrue);
      expect(settings.isWorkDay(date, contextId: otherContextId), isFalse);
    });

    test('a context day off leaves the global day and other contexts alone', () async {
      await makeEveryDayAWorkDay();
      final date = DateTime(2026, 9, 21);
      await settings.setContextDayOverride(contextId, date, 'off');

      expect(settings.isWorkDay(date), isTrue);
      expect(settings.isWorkDay(date, contextId: contextId), isFalse);
      expect(settings.isWorkDay(date, contextId: otherContextId), isTrue);
    });

    test('an extra work day is worth the weekday hours even when disabled', () async {
      await settings.setWorkDaySchedule(7, const WorkDaySchedule(start: '08:00', end: '12:00', enabled: false));
      final sunday = DateTime(2026, 9, 6);
      await settings.setContextDayOverride(contextId, sunday, 'work');

      expect(settings.getExpectedHoursForDate(sunday, contextId: contextId), 4);
      expect(settings.getExpectedHoursForDate(sunday), 0);
    });
  });

  group('settings keys', () {
    test('context day overrides survive a full export and restore', () async {
      final date = DateTime(2026, 9, 21);
      await settings.setContextDayOverride(contextId, date, 'off');
      await settings.setContextDayOverride(otherContextId, DateTime(2026, 9, 22), 'work');

      final exported = settings.getAllContextDayOverrides();
      expect(exported, {'$contextId|2026-09-21': 'off', '$otherContextId|2026-09-22': 'work'});

      await settings.restoreAllContextDayOverrides(exported);

      expect(settings.getContextDayOverride(contextId, date), 'off');
      expect(settings.getContextDayOverride(otherContextId, DateTime(2026, 9, 22)), 'work');
    });

    test('context keys are never mistaken for global day overrides', () async {
      await settings.setDayOverride(DateTime(2026, 9, 1), 'off');
      await settings.setContextDayOverride(contextId, DateTime(2026, 9, 21), 'off');

      expect(settings.getAllDayOverrides(), {'2026-09-01': 'off'});
    });

    test('restoring global day overrides leaves context overrides intact', () async {
      await settings.setContextDayOverride(contextId, DateTime(2026, 9, 21), 'off');
      await settings.restoreAllDayOverrides({'2026-09-02': 'work'});

      expect(settings.getContextDayOverride(contextId, DateTime(2026, 9, 21)), 'off');
    });

    test('every kind of context setting reports the same context id', () async {
      await settings.setContextUsesOwnSchedule(contextId, true);
      await settings.setContextOwnDaySchedule(contextId, 3, const WorkDaySchedule(start: '08:00', end: '12:00', enabled: true));
      await settings.setContextDayOverride(contextId, DateTime(2026, 9, 21), 'off');
      await settings.setContextMonthTarget(contextId, 2026, 12, 120);

      expect(settings.getContextIdsWithSettings(), {contextId});
    });

    test('clearing context settings keeps the global schedule', () async {
      await settings.setWorkDaySchedule(1, const WorkDaySchedule(start: '07:00', end: '15:00', enabled: true));
      await settings.setContextUsesOwnSchedule(contextId, true);
      await settings.setContextMonthTarget(contextId, 2026, 12, 120);

      await settings.clearAllContextSettings();

      expect(settings.getContextIdsWithSettings(), isEmpty);
      expect(settings.getContextUsesOwnSchedule(contextId), isFalse);
      expect(settings.getWorkDaySchedule(1), const WorkDaySchedule(start: '07:00', end: '15:00', enabled: true));
    });
  });

  group('month goals', () {
    test('the default goal applies to every month without an exception', () {
      expect(calculator.targetHoursFor(target(), 2026, 9), 160);
      expect(calculator.targetHoursFor(target(), 2026, 12), 160);
    });

    test('a month exception replaces the default for that month only', () async {
      await settings.setContextMonthTarget(contextId, 2026, 12, 120);

      expect(calculator.targetHoursFor(target(), 2026, 12), 120);
      expect(calculator.targetHoursFor(target(), 2026, 11), 160);
      // Another context with the same months is unaffected.
      expect(calculator.targetHoursFor(target(id: otherContextId), 2026, 12), 160);
    });
  });

  group('remaining work days', () {
    test('a past month has none left', () async {
      await makeEveryDayAWorkDay();
      final lastMonth = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);

      expect(calculator.remainingWorkDays(monthStart: lastMonth, hasWorkedToday: false), 0);
    });

    test('today counts until something is tracked on it', () async {
      await makeEveryDayAWorkDay();
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

      expect(calculator.remainingWorkDays(monthStart: monthStart, hasWorkedToday: false), daysInMonth - now.day + 1);
      expect(calculator.remainingWorkDays(monthStart: monthStart, hasWorkedToday: true), daysInMonth - now.day);
    });

    test("a context's own days off shorten only its own count", () async {
      await makeEveryDayAWorkDay();
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0);
      await settings.setContextDayOverride(contextId, lastDay, 'off');

      final global = calculator.remainingWorkDays(monthStart: monthStart, hasWorkedToday: false);
      final own = calculator.remainingWorkDays(monthStart: monthStart, hasWorkedToday: false, contextId: contextId);

      expect(own, global - 1);
    });

    test('a month with a daylight saving change visits every day once', () async {
      await makeEveryDayAWorkDay();
      await settings.setContextDayOverride(contextId, DateTime(2026, 10, 31), 'off');

      expect(calculator.workDaysBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 31), contextId: contextId), 30);
      expect(calculator.workDaysBetween(DateTime(2026, 3, 1), DateTime(2026, 3, 31), contextId: contextId), 31);
    });
  });

  group('progress', () {
    test('worked hours are summed across the projects of the target', () async {
      await makeEveryDayAWorkDay();
      final now = DateTime.now();

      final progress = calculator.progressFor(
        [
          target(projectIds: ['p1', 'p2']),
        ],
        monthStart: DateTime(now.year, now.month, 1),
        hoursPerProject: {'p1': 30, 'p2': 12.5, 'p3': 99},
        todayHoursPerProject: const {},
      ).single;

      expect(progress.workedHours, 42.5);
      expect(progress.remainingHours, 117.5);
      expect(progress.isComplete, isFalse);
    });

    test('a met goal reports no remaining hours and no daily need', () async {
      await makeEveryDayAWorkDay();
      final now = DateTime.now();

      final progress = calculator.progressFor(
        [target(hours: 100)],
        monthStart: DateTime(now.year, now.month, 1),
        hoursPerProject: const {'p1': 140},
        todayHoursPerProject: const {},
      ).single;

      expect(progress.isComplete, isTrue);
      expect(progress.remainingHours, 0);
      expect(progress.dailyNeeded, 0);
      expect(progress.progress, 1.0);
    });

    test('only the hours of the target itself decide whether today is spent', () async {
      await makeEveryDayAWorkDay();
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      // Work was tracked today, but on a project this target does not cover.
      final progress = calculator.progressFor(
        [target()],
        monthStart: monthStart,
        hoursPerProject: const {'p9': 8},
        todayHoursPerProject: const {'p9': 8},
      ).single;

      expect(progress.remainingWorkDays, calculator.remainingWorkDays(monthStart: monthStart, hasWorkedToday: false));
    });
  });
}
