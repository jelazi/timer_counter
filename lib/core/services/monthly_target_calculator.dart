import 'package:flutter/foundation.dart';

import '../../data/models/monthly_hours_target_model.dart';
import '../../data/repositories/settings_repository.dart';

/// How one monthly target stands in a given month.
@immutable
class MonthlyTargetProgress {
  final MonthlyHoursTargetModel target;

  /// Goal that applies to this month — the target's default unless the month
  /// has an exception of its own.
  final double targetHours;

  final double workedHours;

  /// Work days left in the month according to the target's own schedule, or the
  /// global one when it has none.
  final int remainingWorkDays;

  const MonthlyTargetProgress({required this.target, required this.targetHours, required this.workedHours, required this.remainingWorkDays});

  bool get isComplete => workedHours >= targetHours;

  double get remainingHours => (targetHours - workedHours).clamp(0.0, double.infinity);

  double get progress => targetHours > 0 ? (workedHours / targetHours).clamp(0.0, 1.0) : 0.0;

  /// Hours per remaining work day needed to still make the goal.
  double get dailyNeeded => remainingWorkDays > 0 && !isComplete ? remainingHours / remainingWorkDays : 0.0;
}

/// Turns tracked hours into per-target progress, using each target's own work
/// schedule and day overrides where it has them.
///
/// The three screens that show remaining hours all derive their numbers here so
/// they cannot drift apart.
class MonthlyTargetCalculator {
  final SettingsRepository _settings;

  const MonthlyTargetCalculator(this._settings);

  /// Goal for [year]/[month]: the month's exception, else the target's default.
  double targetHoursFor(MonthlyHoursTargetModel target, int year, int month) {
    return _settings.getContextMonthTarget(target.id, year, month) ?? target.targetHours;
  }

  /// Work days in `[from, to]` inclusive, counted for [contextId]'s schedule.
  int workDaysBetween(DateTime from, DateTime to, {String? contextId}) {
    int count = 0;
    for (DateTime d = _dayOf(from); !d.isAfter(_dayOf(to)); d = DateTime(d.year, d.month, d.day + 1)) {
      if (_settings.isWorkDay(d, contextId: contextId)) count++;
    }
    return count;
  }

  /// Work days left in the month starting at [monthStart].
  ///
  /// A work day that already has hours tracked on it does not count towards the
  /// days the remaining hours still have to be spread over.
  int remainingWorkDays({required DateTime monthStart, required bool hasWorkedToday, String? contextId}) {
    final lastDayOfMonth = DateTime(monthStart.year, monthStart.month + 1, 0);
    final today = _dayOf(DateTime.now());
    final start = _dayOf(monthStart);

    final baseCountFrom = today.isAfter(start) ? today : start;
    final skipToday = hasWorkedToday && baseCountFrom == today && _settings.isWorkDay(today, contextId: contextId);
    final countFrom = skipToday ? DateTime(today.year, today.month, today.day + 1) : baseCountFrom;

    if (countFrom.isAfter(lastDayOfMonth)) return 0;
    return workDaysBetween(countFrom, lastDayOfMonth, contextId: contextId);
  }

  /// Progress of every [targets] entry for the month containing [monthStart].
  ///
  /// [hoursPerProject] holds the hours tracked in that month per project id and
  /// [todayHoursPerProject] the subset tracked today; both include running
  /// timers where the caller accounts for them.
  List<MonthlyTargetProgress> progressFor(
    List<MonthlyHoursTargetModel> targets, {
    required DateTime monthStart,
    required Map<String, double> hoursPerProject,
    required Map<String, double> todayHoursPerProject,
  }) {
    return targets.map((target) {
      final worked = _sumOf(target, hoursPerProject);
      return MonthlyTargetProgress(
        target: target,
        targetHours: targetHoursFor(target, monthStart.year, monthStart.month),
        workedHours: worked,
        remainingWorkDays: remainingWorkDays(monthStart: monthStart, hasWorkedToday: _sumOf(target, todayHoursPerProject) > 0, contextId: target.id),
      );
    }).toList();
  }

  double _sumOf(MonthlyHoursTargetModel target, Map<String, double> hoursPerProject) {
    return target.projectIds.fold(0.0, (sum, id) => sum + (hoursPerProject[id] ?? 0));
  }

  static DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);
}
