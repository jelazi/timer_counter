import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:timer_counter/core/utils/calendar_day.dart';
import 'package:timer_counter/data/models/time_entry_model.dart';
import 'package:timer_counter/data/repositories/time_entry_repository.dart';

void main() {
  late Directory tempDir;
  late TimeEntryRepository repo;

  setUpAll(() {
    Hive.registerAdapter(TimeEntryModelAdapter());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('timer_counter_time_entry_test');
    Hive.init(tempDir.path);
    repo = TimeEntryRepository();
    await repo.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> addEntry(String id, DateTime start) {
    return repo.add(
      TimeEntryModel(id: id, projectId: 'p1', taskId: 't1', startTime: start, endTime: start.add(const Duration(minutes: 20)), createdAt: start),
    );
  }

  List<String> idsIn(DateTime start, DateTime end) => repo.getByDateRange(start, end).map((e) => e.id).toList();

  group('day and week ranges across a daylight saving change', () {
    setUp(() async {
      await addEntry('sat-late', DateTime(2026, 10, 24, 23, 30));
      await addEntry('sun-late', DateTime(2026, 10, 25, 23, 30));
      await addEntry('mon-early', DateTime(2026, 10, 26, 0, 30));
    });

    test('an entry late on the 25-hour day belongs to that day', () {
      final day = DateTime(2026, 10, 25);
      expect(idsIn(day, addCalendarDays(day, 1)), ['sun-late']);
    });

    test('the last evening of a week with the change belongs to that week', () {
      final monday = DateTime(2026, 10, 19);
      expect(idsIn(monday, addCalendarDays(monday, 7)), unorderedEquals(['sat-late', 'sun-late']));
    });

    test('the day after the change does not pick up the previous evening', () {
      final day = DateTime(2026, 10, 26);
      expect(idsIn(day, addCalendarDays(day, 1)), ['mon-early']);
    });
  });

  test('the first hour after the 23-hour day is not counted in it', () async {
    await addEntry('sun', DateTime(2026, 3, 29, 22, 0));
    await addEntry('mon-early', DateTime(2026, 3, 30, 0, 30));

    final day = DateTime(2026, 3, 29);
    expect(idsIn(day, addCalendarDays(day, 1)), ['sun']);
  });
}
