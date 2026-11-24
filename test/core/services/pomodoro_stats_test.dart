import 'package:flutter_test/flutter_test.dart';
import 'package:timer_counter/core/services/pomodoro_engine.dart';
import 'package:timer_counter/core/services/pomodoro_stats.dart';
import 'package:timer_counter/data/models/pomodoro_session.dart';
import 'package:timer_counter/data/models/pomodoro_settings.dart';

void main() {
  // Tuesday.
  final now = DateTime(2026, 11, 24, 15);

  PomodoroSessionRecord record(String id, DateTime ended, {int pomodoros = 2, int work = 3000}) => PomodoroSessionRecord(
    id: id,
    startedAt: ended.subtract(const Duration(hours: 1)),
    endedAt: ended,
    endReason: PomodoroEndReason.manual,
    completedPomodoros: pomodoros,
    workSeconds: work,
  );

  final records = [
    record('today', DateTime(2026, 11, 24, 10)),
    record('monday', DateTime(2026, 11, 23, 18), pomodoros: 3, work: 4500),
    record('last-sunday', DateTime(2026, 11, 22, 20), pomodoros: 4, work: 6000),
  ];

  test('the week starts on Monday at midnight', () {
    expect(PomodoroStats.startOfWeek(now), DateTime(2026, 11, 23));
    expect(PomodoroStats.startOfWeek(DateTime(2026, 11, 29, 23)), DateTime(2026, 11, 23));
    expect(PomodoroStats.startOfWeek(DateTime(2026, 11, 23, 0, 30)), DateTime(2026, 11, 23));
  });

  test('today and this week count finished sessions plus the running one', () {
    final active = PomodoroEngine.advance(
      PomodoroEngine.start(id: 'live', settings: const PomodoroSettings(), now: DateTime(2026, 11, 24, 14)),
      const PomodoroSettings(),
      now,
    ).session!;
    expect(active.completedPomodoros, 1);
    expect(active.isAwaitingStart, isTrue);

    final today = PomodoroStats.summarize(records, active, PomodoroStats.startOfDay(now), now);
    expect(today, PomodoroSummary(pomodoros: 3, workSeconds: 3000 + active.liveWorkSeconds(now), sessions: 2));

    final week = PomodoroStats.summarize(records, null, PomodoroStats.startOfWeek(now), now);
    expect(week, const PomodoroSummary(pomodoros: 5, workSeconds: 7500, sessions: 2));
  });

  test('a record of the running session is not counted twice', () {
    final active = PomodoroEngine.start(id: 'today', settings: const PomodoroSettings(), now: DateTime(2026, 11, 24, 14));
    expect(PomodoroStats.summarize(records, active, PomodoroStats.startOfDay(now), now).sessions, 1);
  });

  test('history groups by day, newest first', () {
    final groups = PomodoroStats.byDay([...records, record('today-later', DateTime(2026, 11, 24, 12))]);
    expect(groups.map((g) => g.day), [DateTime(2026, 11, 24), DateTime(2026, 11, 23), DateTime(2026, 11, 22)]);
    expect(groups.first.records.map((r) => r.id), ['today-later', 'today']);
  });
}
