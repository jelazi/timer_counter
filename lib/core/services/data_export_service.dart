import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/project_client_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';

/// Time entries exported in Timer Counter's own format, as JSON or CSV.
///
/// JSON: `{format, version, exported_at, period, currency, summary, entries[]}`.
/// CSV: one row per entry, `;`-separated, the same fields as a JSON entry.
class DataExportService {
  static const String format = 'timer_counter.export';
  static const int version = 1;

  static const List<String> csvColumns = [
    'date',
    'start',
    'end',
    'duration_minutes',
    'hours',
    'project',
    'task',
    'clients',
    'billable',
    'hourly_rate',
    'amount',
    'currency',
    'notes',
  ];

  final TimeEntryRepository _timeEntryRepository;
  final ProjectRepository _projectRepository;
  final TaskRepository _taskRepository;
  final ClientRepository _clientRepository;
  final ProjectClientRepository _projectClientRepository;
  final SettingsRepository _settingsRepository;

  DataExportService({
    required TimeEntryRepository timeEntryRepository,
    required ProjectRepository projectRepository,
    required TaskRepository taskRepository,
    required ClientRepository clientRepository,
    required ProjectClientRepository projectClientRepository,
    required SettingsRepository settingsRepository,
  }) : _timeEntryRepository = timeEntryRepository,
       _projectRepository = projectRepository,
       _taskRepository = taskRepository,
       _clientRepository = clientRepository,
       _projectClientRepository = projectClientRepository,
       _settingsRepository = settingsRepository;

  /// The entries of the period as export records, oldest first.
  List<Map<String, dynamic>> buildEntries({DateTime? startDate, DateTime? endDate}) {
    final entries = (startDate != null && endDate != null) ? _timeEntryRepository.getByDateRange(startDate, endDate) : _timeEntryRepository.getAll();
    final sorted = [...entries]..sort((a, b) => a.startTime.compareTo(b.startTime));
    final roundTime = _settingsRepository.getRoundTime();
    final roundToMinutes = _settingsRepository.getRoundToMinutes();
    final currency = _settingsRepository.getCurrency();

    return [
      for (final entry in sorted)
        () {
          final project = _projectRepository.getById(entry.projectId);
          final task = _taskRepository.getById(entry.taskId);
          final minutes = durationMinutes(entry, roundTime: roundTime, roundToMinutes: roundToMinutes);
          final rate = hourlyRate(project, task);
          final end = entry.endTime ?? entry.startTime.add(Duration(seconds: entry.durationSeconds));
          return <String, dynamic>{
            'id': entry.id,
            'date': DateFormat('yyyy-MM-dd').format(entry.startTime),
            'start': entry.startTime.toIso8601String(),
            'end': end.toIso8601String(),
            'duration_minutes': minutes,
            'hours': _round2(minutes / 60.0),
            'project': project?.name ?? '',
            'project_id': entry.projectId,
            'task': task?.name ?? '',
            'task_id': entry.taskId,
            'clients': _clientNames(entry.projectId),
            'billable': entry.isBillable,
            'hourly_rate': rate,
            'amount': entry.isBillable ? _round2(minutes / 60.0 * rate) : 0.0,
            'currency': currency,
            'notes': entry.notes,
          };
        }(),
    ];
  }

  Future<String> exportToJson({String? outputPath, DateTime? startDate, DateTime? endDate}) async {
    final entries = buildEntries(startDate: startDate, endDate: endDate);
    final document = {
      'format': format,
      'version': version,
      'exported_at': DateTime.now().toIso8601String(),
      'period': {'from': startDate == null ? null : DateFormat('yyyy-MM-dd').format(startDate), 'to': endDate == null ? null : DateFormat('yyyy-MM-dd').format(endDate)},
      'currency': _settingsRepository.getCurrency(),
      'summary': {
        'entries': entries.length,
        'hours': _round2(entries.fold<double>(0, (sum, e) => sum + (e['duration_minutes'] as int) / 60.0)),
        'amount': _round2(entries.fold<double>(0, (sum, e) => sum + (e['amount'] as double))),
      },
      'entries': entries,
    };
    final path = outputPath ?? await _defaultPath('json');
    await File(path).writeAsString(const JsonEncoder.withIndent('  ').convert(document));
    return path;
  }

  Future<String> exportToCsv({String? outputPath, DateTime? startDate, DateTime? endDate}) async {
    final entries = buildEntries(startDate: startDate, endDate: endDate);
    final rows = <List<dynamic>>[
      csvColumns,
      for (final e in entries)
        [
          e['date'],
          DateFormat('HH:mm').format(DateTime.parse(e['start'] as String)),
          DateFormat('HH:mm').format(DateTime.parse(e['end'] as String)),
          e['duration_minutes'],
          _decimal(e['hours'] as double),
          e['project'],
          e['task'],
          (e['clients'] as List<String>).join(', '),
          (e['billable'] as bool) ? 'ano' : 'ne',
          _decimal(e['hourly_rate'] as double),
          _decimal(e['amount'] as double),
          e['currency'],
          e['notes'],
        ],
    ];
    final path = outputPath ?? await _defaultPath('csv');
    await File(path).writeAsString(const CsvEncoder(fieldDelimiter: ';').convert(rows));
    return path;
  }

  /// Whole minutes, rounded to the configured step when rounding is on; never zero.
  static int durationMinutes(TimeEntryModel entry, {required bool roundTime, required int roundToMinutes}) {
    var minutes = (entry.actualDurationSeconds / 60.0).round();
    if (roundTime && roundToMinutes > 1) {
      minutes = ((minutes + roundToMinutes ~/ 2) ~/ roundToMinutes) * roundToMinutes;
    }
    return minutes < 1 ? 1 : minutes;
  }

  /// A task's own rate wins over the project's.
  static double hourlyRate(ProjectModel? project, TaskModel? task) {
    final taskRate = task?.hourlyRate;
    if (taskRate != null && taskRate > 0) return taskRate;
    return project?.hourlyRate ?? 0.0;
  }

  List<String> _clientNames(String projectId) =>
      _projectClientRepository.getByProject(projectId).map((l) => _clientRepository.getById(l.clientId)?.name).whereType<String>().toList();

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  static String _decimal(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  Future<String> _defaultPath(String extension) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    return '${dir.path}/timer_counter_export_$timestamp.$extension';
  }
}
