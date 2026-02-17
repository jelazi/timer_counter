import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../data/models/category_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';

class TymeExportService {
  final TimeEntryRepository _timeEntryRepository;
  final ProjectRepository _projectRepository;
  final TaskRepository _taskRepository;
  final CategoryRepository _categoryRepository;
  final SettingsRepository _settingsRepository;

  TymeExportService({
    required TimeEntryRepository timeEntryRepository,
    required ProjectRepository projectRepository,
    required TaskRepository taskRepository,
    required CategoryRepository categoryRepository,
    required SettingsRepository settingsRepository,
  })  : _timeEntryRepository = timeEntryRepository,
        _projectRepository = projectRepository,
        _taskRepository = taskRepository,
        _categoryRepository = categoryRepository,
        _settingsRepository = settingsRepository;

  /// Export all time entries in Tyme-compatible JSON format.
  /// Returns the path of the exported file.
  Future<String> exportToJson({String? outputPath, DateTime? startDate, DateTime? endDate}) async {
    List<TimeEntryModel> entries;
    if (startDate != null && endDate != null) {
      entries = _timeEntryRepository.getByDateRange(startDate, endDate);
    } else {
      entries = _timeEntryRepository.getAll();
    }

    final currency = _settingsRepository.getCurrency();
    final roundTime = _settingsRepository.getRoundTime();
    final roundToMinutes = _settingsRepository.getRoundToMinutes();

    final data = entries.map((entry) {
      final project = _projectRepository.getById(entry.projectId);
      final task = _taskRepository.getById(entry.taskId);
      CategoryModel? category;
      if (project?.categoryId != null) {
        category = _categoryRepository.getById(project!.categoryId!);
      }

      final durationMinutes = _calculateDurationMinutes(entry, roundTime, roundToMinutes);
      final rate = _getRate(project, task);
      final sum = (durationMinutes / 60.0) * rate;

      return _buildEntryJson(
        entry: entry,
        project: project,
        task: task,
        category: category,
        durationMinutes: durationMinutes,
        rate: rate,
        sum: sum,
        currency: currency,
        roundToMinutes: roundToMinutes,
        roundMethod: roundTime ? 'NEAREST' : 'NEAREST',
      );
    }).toList();

    final jsonOutput = const JsonEncoder.withIndent('  ').convert({'data': data});

    final filePath = outputPath ?? await _getDefaultExportPath();
    final file = File(filePath);
    await file.writeAsString(jsonOutput);

    return filePath;
  }

  int _calculateDurationMinutes(TimeEntryModel entry, bool roundTime, int roundToMinutes) {
    final totalSeconds = entry.actualDurationSeconds;
    var minutes = (totalSeconds / 60.0).round();

    if (roundTime && roundToMinutes > 1) {
      minutes = ((minutes + roundToMinutes ~/ 2) ~/ roundToMinutes) * roundToMinutes;
    }

    return minutes < 1 ? 1 : minutes;
  }

  double _getRate(ProjectModel? project, TaskModel? task) {
    // Task rate overrides project rate
    if (task?.hourlyRate != null && task!.hourlyRate! > 0) {
      return task.hourlyRate!;
    }
    return project?.hourlyRate ?? 0.0;
  }

  Map<String, dynamic> _buildEntryJson({
    required TimeEntryModel entry,
    ProjectModel? project,
    TaskModel? task,
    CategoryModel? category,
    required int durationMinutes,
    required double rate,
    required double sum,
    required String currency,
    required int roundToMinutes,
    required String roundMethod,
  }) {
    // Date formatted as ISO 8601 with timezone (just date, no time — matching Tyme format)
    final date = entry.startTime;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final offset = date.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final mins = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final dateStr = '${dateOnly.toIso8601String().split('.').first}$sign$hours:$mins';

    return {
      'billing': entry.isBillable ? 'UNBILLED' : 'NON_BILLABLE',
      'category': category?.name ?? '',
      'category_id': category?.id ?? '',
      'date': dateStr,
      'distance': 0,
      'distance_unit': 'km',
      'duration': durationMinutes,
      'duration_unit': 'm',
      'id': entry.id,
      'note': entry.notes,
      'project': project?.name ?? '',
      'project_id': project?.id ?? '',
      'quantity': 0,
      'rate': rate,
      'rate_unit': currency,
      'rounding_method': roundMethod,
      'rounding_minutes': roundToMinutes,
      'subtask': '',
      'subtask_id': '',
      'sum': sum,
      'sum_unit': currency,
      'task': task?.name ?? '',
      'task_id': task?.id ?? '',
      'type': 'timed',
      'user': '',
      'user_id': 'ID_LOCAL_USER',
    };
  }

  Future<String> _getDefaultExportPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    return '${dir.path}/tyme_export_$timestamp.json';
  }
}
