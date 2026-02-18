import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/category_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';

enum ImportMode { overwrite, append, merge }

class ImportResult {
  final int categoriesImported;
  final int projectsImported;
  final int tasksImported;
  final int entriesImported;
  final String? error;

  const ImportResult({this.categoriesImported = 0, this.projectsImported = 0, this.tasksImported = 0, this.entriesImported = 0, this.error});

  bool get hasError => error != null;
}

class TymeImportService {
  final TimeEntryRepository _timeEntryRepository;
  final ProjectRepository _projectRepository;
  final TaskRepository _taskRepository;
  final CategoryRepository _categoryRepository;

  TymeImportService({
    required TimeEntryRepository timeEntryRepository,
    required ProjectRepository projectRepository,
    required TaskRepository taskRepository,
    required CategoryRepository categoryRepository,
  }) : _timeEntryRepository = timeEntryRepository,
       _projectRepository = projectRepository,
       _taskRepository = taskRepository,
       _categoryRepository = categoryRepository;

  Future<ImportResult> importFromJson(String filePath, ImportMode mode) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const ImportResult(error: 'File not found');
      }

      final content = await file.readAsString();
      final jsonData = jsonDecode(content);

      if (jsonData is! Map<String, dynamic> || !jsonData.containsKey('data')) {
        return const ImportResult(error: 'Invalid format: missing "data" key');
      }

      final List<dynamic> entries = jsonData['data'];
      if (entries.isEmpty) {
        return const ImportResult(error: 'No data found in file');
      }

      // If overwrite mode, clear all existing data first
      if (mode == ImportMode.overwrite) {
        await _clearAllData();
      }

      // Get existing entities for name-based deduplication
      final existingCategories = _categoryRepository.getAll();
      final existingProjects = _projectRepository.getAll();
      final existingTasks = _taskRepository.getAll();

      // ID mappings: import file ID → database ID (for reusing existing entities)
      final Map<String, String> catIdMap = {};
      final Map<String, String> projIdMap = {};
      final Map<String, String> taskIdMap = {};

      // Entities to create (only truly new ones)
      final categoriesToCreate = <String, CategoryModel>{};
      final projectsToCreate = <String, ProjectModel>{};
      final tasksToCreate = <String, TaskModel>{};

      // Day stacking tracker: entries on the same day start after the previous one
      final Map<String, DateTime> dayNextStart = {};

      final timeEntries = <TimeEntryModel>[];

      for (final entry in entries) {
        if (entry is! Map<String, dynamic>) continue;

        final categoryId = entry['category_id'] as String? ?? '';
        final categoryName = entry['category'] as String? ?? '';
        final projectId = entry['project_id'] as String? ?? '';
        final projectName = entry['project'] as String? ?? '';
        final taskId = entry['task_id'] as String? ?? '';
        final taskName = entry['task'] as String? ?? '';
        final rate = (entry['rate'] as num?)?.toDouble() ?? 0.0;
        final billing = entry['billing'] as String? ?? '';

        // Category: check by name first to avoid duplicates
        if (categoryId.isNotEmpty && categoryName.isNotEmpty && !catIdMap.containsKey(categoryId)) {
          final existingByName = existingCategories.where((c) => c.name.toLowerCase() == categoryName.toLowerCase()).toList();
          if (existingByName.isNotEmpty) {
            catIdMap[categoryId] = existingByName.first.id;
          } else {
            catIdMap[categoryId] = categoryId;
            categoriesToCreate[categoryId] = CategoryModel(id: categoryId, name: categoryName, colorValue: 0xFF6366F1, createdAt: DateTime.now());
          }
        }

        // Project: check by name first to avoid duplicates
        if (projectId.isNotEmpty && projectName.isNotEmpty && !projIdMap.containsKey(projectId)) {
          final existingByName = existingProjects.where((p) => p.name.toLowerCase() == projectName.toLowerCase()).toList();
          if (existingByName.isNotEmpty) {
            projIdMap[projectId] = existingByName.first.id;
          } else {
            final actualCatId = catIdMap[categoryId] ?? (categoryId.isNotEmpty ? categoryId : null);
            projIdMap[projectId] = projectId;
            projectsToCreate[projectId] = ProjectModel(
              id: projectId,
              name: projectName,
              categoryId: actualCatId,
              colorValue: 0xFF6366F1,
              hourlyRate: rate,
              isBillable: billing != 'NON_BILLABLE',
              createdAt: DateTime.now(),
            );
          }
        }

        // Task: check by name within the same project to avoid duplicates
        if (taskId.isNotEmpty && taskName.isNotEmpty && !taskIdMap.containsKey(taskId)) {
          final actualProjId = projIdMap[projectId] ?? projectId;
          final existingByName = existingTasks.where((t) => t.name.toLowerCase() == taskName.toLowerCase() && t.projectId == actualProjId).toList();
          if (existingByName.isNotEmpty) {
            taskIdMap[taskId] = existingByName.first.id;
          } else {
            taskIdMap[taskId] = taskId;
            tasksToCreate[taskId] = TaskModel(id: taskId, projectId: actualProjId, name: taskName, isBillable: billing != 'NON_BILLABLE', createdAt: DateTime.now());
          }
        }

        // Build time entry with correct date/time
        final entryId = entry['id'] as String? ?? const Uuid().v4();
        final dateStr = entry['date'] as String? ?? '';
        final durationMinutes = (entry['duration'] as num?)?.toInt() ?? 0;
        final note = entry['note'] as String? ?? '';

        if (dateStr.isEmpty || durationMinutes <= 0) continue;

        // Parse date correctly — convert to local to get the right calendar date
        DateTime localDate;
        try {
          final parsed = DateTime.parse(dateStr);
          localDate = parsed.toLocal();
        } catch (_) {
          continue;
        }

        // Stack entries through the day starting from 8:00 AM
        final dayKey = '${localDate.year}-${localDate.month}-${localDate.day}';
        DateTime startTime;
        if (dayNextStart.containsKey(dayKey)) {
          startTime = dayNextStart[dayKey]!;
        } else {
          startTime = DateTime(localDate.year, localDate.month, localDate.day, 8, 0);
        }
        final endTime = startTime.add(Duration(minutes: durationMinutes));
        dayNextStart[dayKey] = endTime;

        final actualProjectId = projIdMap[projectId] ?? projectId;
        final actualTaskId = taskIdMap[taskId] ?? taskId;

        timeEntries.add(
          TimeEntryModel(
            id: entryId,
            projectId: actualProjectId,
            taskId: actualTaskId,
            startTime: startTime,
            endTime: endTime,
            durationSeconds: durationMinutes * 60,
            notes: note,
            createdAt: DateTime.now(),
            isBillable: billing != 'NON_BILLABLE',
          ),
        );
      }

      // Import in dependency order
      int catCount = 0, projCount = 0, taskCount = 0, entryCount = 0;

      for (final category in categoriesToCreate.values) {
        if (mode == ImportMode.merge) {
          final existing = _categoryRepository.getById(category.id);
          if (existing != null) {
            await _categoryRepository.update(category.copyWith(createdAt: existing.createdAt));
          } else {
            await _categoryRepository.add(category);
          }
        } else {
          await _categoryRepository.add(category);
        }
        catCount++;
      }

      for (final project in projectsToCreate.values) {
        if (mode == ImportMode.merge) {
          final existing = _projectRepository.getById(project.id);
          if (existing != null) {
            await _projectRepository.update(project.copyWith(colorValue: existing.colorValue, createdAt: existing.createdAt));
          } else {
            await _projectRepository.add(project);
          }
        } else {
          await _projectRepository.add(project);
        }
        projCount++;
      }

      for (final task in tasksToCreate.values) {
        if (mode == ImportMode.merge) {
          final existing = _taskRepository.getById(task.id);
          if (existing != null) {
            await _taskRepository.update(task.copyWith(createdAt: existing.createdAt));
          } else {
            await _taskRepository.add(task);
          }
        } else {
          await _taskRepository.add(task);
        }
        taskCount++;
      }

      for (final entry in timeEntries) {
        if (mode == ImportMode.merge) {
          final existing = _timeEntryRepository.getById(entry.id);
          if (existing != null) {
            await _timeEntryRepository.update(entry.copyWith(createdAt: existing.createdAt));
          } else {
            await _timeEntryRepository.add(entry);
          }
        } else {
          await _timeEntryRepository.add(entry);
        }
        entryCount++;
      }

      return ImportResult(categoriesImported: catCount, projectsImported: projCount, tasksImported: taskCount, entriesImported: entryCount);
    } catch (e) {
      debugPrint('Import error: $e');
      return ImportResult(error: e.toString());
    }
  }

  Future<ImportResult> importFromCsv(String filePath, ImportMode mode) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const ImportResult(error: 'File not found');
      }

      final content = await file.readAsString();
      final rows = const CsvDecoder(fieldDelimiter: ';').convert(content);

      if (rows.length < 2) {
        return const ImportResult(error: 'CSV file is empty or has no data rows');
      }

      // First row is header
      final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      final dataRows = rows.skip(1).toList();

      int col(String name) => header.indexOf(name);
      final iCategory = col('category');
      final iProject = col('project');
      final iTask = col('task');
      final iUnixStart = col('unix_start');
      final iUnixEnd = col('unix_end');
      final iDate = col('date');
      final iStartTime = col('start_time');
      final iEndTime = col('end_time');
      final iDuration = col('duration');
      final iRate = col('rate');
      final iBilling = col('billing');
      final iNote = col('note');

      // Convert CSV rows to the same format as JSON entries for reuse
      final entries = <Map<String, dynamic>>[];
      for (final row in dataRows) {
        if (row.isEmpty) continue;
        String val(int idx) => idx >= 0 && idx < row.length ? row[idx].toString().trim() : '';

        final categoryName = val(iCategory);
        final projectName = val(iProject);
        final taskName = val(iTask);
        final note = iNote >= 0 ? val(iNote).replaceAll('"', '') : '';
        final billing = val(iBilling);

        // Parse rate (handles European format: space thousands, comma decimal)
        double rate = 0;
        if (iRate >= 0) {
          final rateStr = val(iRate).replaceAll(' ', '').replaceAll(',', '.');
          rate = double.tryParse(rateStr) ?? 0;
        }

        // Parse start/end times
        DateTime? startTime;
        DateTime? endTime;

        // Try unix timestamps first
        if (iUnixStart >= 0 && val(iUnixStart).isNotEmpty) {
          final unixStart = int.tryParse(val(iUnixStart));
          if (unixStart != null && unixStart > 0) {
            startTime = DateTime.fromMillisecondsSinceEpoch(unixStart * 1000);
          }
        }
        if (iUnixEnd >= 0 && val(iUnixEnd).isNotEmpty) {
          final unixEnd = int.tryParse(val(iUnixEnd));
          if (unixEnd != null && unixEnd > 0) {
            endTime = DateTime.fromMillisecondsSinceEpoch(unixEnd * 1000);
          }
        }

        // Fallback to date + time columns
        if (startTime == null && iDate >= 0 && iStartTime >= 0) {
          final dateStr = val(iDate);
          final timeStr = val(iStartTime);
          if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
            try {
              startTime = DateFormat('dd.MM.yyyy HH:mm').parse('$dateStr $timeStr');
            } catch (_) {}
          }
        }
        if (endTime == null && iDate >= 0 && iEndTime >= 0) {
          final dateStr = val(iDate);
          final timeStr = val(iEndTime);
          if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
            try {
              endTime = DateFormat('dd.MM.yyyy HH:mm').parse('$dateStr $timeStr');
            } catch (_) {}
          }
        }

        // Parse duration (in minutes)
        int durationMinutes = 0;
        if (iDuration >= 0) {
          final durStr = val(iDuration).replaceAll(' ', '').replaceAll(',', '.');
          durationMinutes = (double.tryParse(durStr) ?? 0).round();
        }

        // If we still have no start time, skip
        if (startTime == null) continue;

        // If no end time, compute from duration
        endTime ??= startTime.add(Duration(minutes: durationMinutes > 0 ? durationMinutes : 1));
        if (durationMinutes <= 0) {
          durationMinutes = endTime.difference(startTime).inMinutes;
        }

        final dateOnly = DateTime(startTime.year, startTime.month, startTime.day);
        final offset = startTime.timeZoneOffset;
        final sign = offset.isNegative ? '-' : '+';
        final hours = offset.inHours.abs().toString().padLeft(2, '0');
        final mins = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
        final dateStr = '${dateOnly.toIso8601String().split('.').first}$sign$hours:$mins';

        // Create a category ID and project ID from names for dedup
        final catId = categoryName.isNotEmpty ? 'csv_cat_${categoryName.toLowerCase().replaceAll(' ', '_')}' : '';
        final projId = projectName.isNotEmpty ? 'csv_proj_${projectName.toLowerCase().replaceAll(' ', '_')}' : '';
        final tskId = taskName.isNotEmpty ? 'csv_task_${projectName.toLowerCase().replaceAll(' ', '_')}_${taskName.toLowerCase().replaceAll(' ', '_')}' : '';

        entries.add({
          'category_id': catId,
          'category': categoryName,
          'project_id': projId,
          'project': projectName,
          'task_id': tskId,
          'task': taskName,
          'id': const Uuid().v4(),
          'date': dateStr,
          'duration': durationMinutes,
          'note': note,
          'rate': rate,
          'billing': billing,
        });
      }

      if (entries.isEmpty) {
        return const ImportResult(error: 'No valid data rows found in CSV');
      }

      // Reuse JSON import logic by creating a temporary JSON-like structure
      // Save to temp file and import via existing importFromJson
      final tempDir = await Directory.systemTemp.createTemp('csv_import_');
      final tempFile = File('${tempDir.path}/csv_import.json');
      await tempFile.writeAsString(jsonEncode({'data': entries}));

      final result = await importFromJson(tempFile.path, mode);

      // Cleanup temp file
      try {
        await tempFile.delete();
        await tempDir.delete();
      } catch (_) {}

      return result;
    } catch (e) {
      debugPrint('CSV Import error: $e');
      return ImportResult(error: e.toString());
    }
  }

  Future<void> _clearAllData() async {
    // Clear in reverse dependency order
    final allEntries = _timeEntryRepository.getAll();
    for (final entry in allEntries) {
      await _timeEntryRepository.delete(entry.id);
    }
    final allTasks = _taskRepository.getAll();
    for (final task in allTasks) {
      await _taskRepository.delete(task.id);
    }
    final allProjects = _projectRepository.getAll();
    for (final project in allProjects) {
      await _projectRepository.delete(project.id);
    }
    final allCategories = _categoryRepository.getAll();
    for (final category in allCategories) {
      await _categoryRepository.delete(category.id);
    }
  }
}
