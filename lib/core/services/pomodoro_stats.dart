import 'package:equatable/equatable.dart';

import '../../data/models/pomodoro_session.dart';
import '../utils/calendar_day.dart';

class PomodoroSummary extends Equatable {
  final int pomodoros;
  final int workSeconds;
  final int sessions;

  const PomodoroSummary({this.pomodoros = 0, this.workSeconds = 0, this.sessions = 0});

  @override
  List<Object?> get props => [pomodoros, workSeconds, sessions];
}

class PomodoroStats {
  const PomodoroStats._();

  static DateTime startOfDay(DateTime now) => DateTime(now.year, now.month, now.day);

  static DateTime startOfWeek(DateTime now) => addCalendarDays(now, 1 - now.weekday);

  /// Finished sessions that ended in `[from, now]`, plus the running one.
  static PomodoroSummary summarize(List<PomodoroSessionRecord> records, PomodoroSession? active, DateTime from, DateTime now) {
    var pomodoros = 0;
    var work = 0;
    var sessions = 0;
    for (final r in records) {
      if (r.endedAt.isBefore(from) || r.endedAt.isAfter(now) || r.id == active?.id) continue;
      pomodoros += r.completedPomodoros;
      work += r.workSeconds;
      sessions++;
    }
    if (active != null) {
      pomodoros += active.completedPomodoros;
      work += active.liveWorkSeconds(now);
      sessions++;
    }
    return PomodoroSummary(pomodoros: pomodoros, workSeconds: work, sessions: sessions);
  }

  /// Records grouped by the day they ended, newest day and newest record first.
  static List<({DateTime day, List<PomodoroSessionRecord> records})> byDay(List<PomodoroSessionRecord> records) {
    final sorted = [...records]..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final groups = <({DateTime day, List<PomodoroSessionRecord> records})>[];
    for (final r in sorted) {
      final day = startOfDay(r.endedAt);
      if (groups.isEmpty || groups.last.day != day) groups.add((day: day, records: <PomodoroSessionRecord>[]));
      groups.last.records.add(r);
    }
    return groups;
  }
}
