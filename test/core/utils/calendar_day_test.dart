import 'package:flutter_test/flutter_test.dart';
import 'package:timer_counter/core/utils/calendar_day.dart';

/// The daylight saving cases only bite in a zone that has DST, which is why
/// CI runs the tests with `TZ=Europe/Prague`.
void main() {
  group('addCalendarDays', () {
    test('lands on the next midnight across the autumn change (25h day)', () {
      expect(addCalendarDays(DateTime(2026, 10, 25), 1), DateTime(2026, 10, 26));
    });

    test('lands on the next midnight across the spring change (23h day)', () {
      expect(addCalendarDays(DateTime(2026, 3, 29), 1), DateTime(2026, 3, 30));
    });

    test('a week that contains a DST change ends on the following Monday', () {
      expect(addCalendarDays(DateTime(2026, 10, 19), 7), DateTime(2026, 10, 26));
      expect(addCalendarDays(DateTime(2026, 3, 23), 7), DateTime(2026, 3, 30));
    });

    test('steps back to the previous midnight across a DST change', () {
      expect(addCalendarDays(DateTime(2026, 3, 30), -1), DateTime(2026, 3, 29));
      expect(addCalendarDays(DateTime(2026, 10, 26), -1), DateTime(2026, 10, 25));
    });

    test('drops the time of day', () {
      expect(addCalendarDays(DateTime(2026, 10, 25, 23, 30), 0), DateTime(2026, 10, 25));
      expect(addCalendarDays(DateTime(2026, 10, 25, 23, 30), 1), DateTime(2026, 10, 26));
    });

    test('rolls over month and year ends', () {
      expect(addCalendarDays(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
      expect(addCalendarDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addCalendarDays(DateTime(2026, 1, 1), -1), DateTime(2025, 12, 31));
    });

    test('walking a DST month day by day visits every date once', () {
      final visited = <int>[];
      for (DateTime d = DateTime(2026, 10, 1); d.month == 10; d = addCalendarDays(d, 1)) {
        expect(d.hour, 0);
        visited.add(d.day);
      }
      expect(visited, List.generate(31, (i) => i + 1));
    });
  });
}
