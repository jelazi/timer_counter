import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timer_counter/core/services/earnings.dart';
import 'package:timer_counter/data/models/project_model.dart';
import 'package:timer_counter/data/models/running_timer_model.dart';
import 'package:timer_counter/data/models/time_entry_model.dart';

void main() {
  final artemis = ProjectModel(id: 'artemis', name: '2. Artemis', colorValue: 0, hourlyRate: 550, createdAt: DateTime(2026));
  final internal = ProjectModel(id: 'internal', name: 'Interní', colorValue: 0, createdAt: DateTime(2026));
  ProjectModel? projectOf(String id) => {'artemis': artemis, 'internal': internal}[id];

  TimeEntryModel entry(String projectId, int minutes, {bool billable = true}) => TimeEntryModel(
    id: '$projectId-$minutes-$billable',
    projectId: projectId,
    taskId: 't',
    startTime: DateTime(2026, 11, 23, 9),
    endTime: DateTime(2026, 11, 23, 9).add(Duration(minutes: minutes)),
    isBillable: billable,
    createdAt: DateTime(2026, 11, 23),
  );

  setUpAll(() => initializeDateFormatting('cs'));

  test('billable time is paid at the project rate', () {
    expect(Earnings.ofEntries([entry('artemis', 90)], projectOf), 825);
  });

  test('non-billable entries, projects without a rate and unknown projects earn nothing', () {
    expect(Earnings.ofEntries([entry('artemis', 60, billable: false), entry('internal', 60), entry('gone', 60)], projectOf), 0);
  });

  test('a running timer counts its elapsed time at the project rate', () {
    final timer = RunningTimerModel(id: 'r', projectId: 'artemis', taskId: 't', startTime: DateTime.now().subtract(const Duration(minutes: 30)));

    expect(Earnings.ofRunning([timer], projectOf), closeTo(275, 1));
  });

  test('per project sums entries and running timers by project', () {
    final timer = RunningTimerModel(id: 'r', projectId: 'artemis', taskId: 't', startTime: DateTime.now().subtract(const Duration(hours: 1)));

    final result = Earnings.perProject([entry('artemis', 60), entry('internal', 60)], [timer], projectOf);

    expect(result.keys, ['artemis']);
    expect(result['artemis'], closeTo(1100, 1));
  });

  test('amounts are whole units with the locale grouping', () {
    expect(Earnings.format(32351.4, 'CZK', 'cs'), '32 351 CZK');
  });
}
