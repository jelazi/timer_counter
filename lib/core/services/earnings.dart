import 'package:intl/intl.dart';

import '../../data/models/project_model.dart';
import '../../data/models/running_timer_model.dart';
import '../../data/models/time_entry_model.dart';

/// Money earned for tracked time: billable time × the project's hourly rate,
/// the same rule the statistics use.
class Earnings {
  Earnings._();

  static double ofEntries(Iterable<TimeEntryModel> entries, ProjectModel? Function(String projectId) projectOf) {
    var sum = 0.0;
    for (final entry in entries) {
      if (!entry.isBillable) continue;
      sum += entry.actualDurationSeconds / 3600 * (projectOf(entry.projectId)?.hourlyRate ?? 0);
    }
    return sum;
  }

  /// A running timer is saved as a billable entry when stopped, so it counts already.
  static double ofRunning(Iterable<RunningTimerModel> timers, ProjectModel? Function(String projectId) projectOf) {
    var sum = 0.0;
    for (final timer in timers) {
      sum += timer.elapsedSeconds / 3600 * (projectOf(timer.projectId)?.hourlyRate ?? 0);
    }
    return sum;
  }

  /// Earnings per project id, for summing over a group of projects.
  static Map<String, double> perProject(Iterable<TimeEntryModel> entries, Iterable<RunningTimerModel> running, ProjectModel? Function(String projectId) projectOf) {
    final result = <String, double>{};
    for (final entry in entries) {
      final amount = ofEntries([entry], projectOf);
      if (amount > 0) result.update(entry.projectId, (v) => v + amount, ifAbsent: () => amount);
    }
    for (final timer in running) {
      final amount = ofRunning([timer], projectOf);
      if (amount > 0) result.update(timer.projectId, (v) => v + amount, ifAbsent: () => amount);
    }
    return result;
  }

  /// Whole currency units with the locale's grouping, e.g. "32 351 CZK".
  static String format(double amount, String currency, String locale) => '${NumberFormat.decimalPattern(locale).format(amount.round())} $currency';
}
