import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  const ImportResult({
    this.categoriesImported = 0,
    this.projectsImported = 0,
    this.tasksImported = 0,
    this.entriesImported = 0,
    this.error,
  });

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
  })  : _timeEntryRepository = timeEntryRepository,
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

      // Extract unique categories, projects, tasks from the import data
      final categories = <String, CategoryModel>{};
      final projects = <String, ProjectModel>{};
      final tasks = <String, TaskModel>{};
      final timeEntries = <TimeEntryModel>[];

      for (final entry in entries) {
        if (entry is! Map<String, dynamic>) continue;

        // Extract category
        final categoryId = entry['category_id'] as String? ?? '';
        final categoryName = entry['category'] as String? ?? '';
        if (categoryId.isNotEmpty && categoryName.isNotEmpty && !categories.containsKey(categoryId)) {
          categories[categoryId] = CategoryModel(
            id: categoryId,
            name: categoryName,
            colorValue: 0xFF6366F1,
            createdAt: DateTime.now(),
          );
        }

        // Extract project
        final projectId = entry['project_id'] as String? ?? '';
        final projectName = entry['project'] as String? ?? '';
        if (projectId.isNotEmpty && projectName.isNotEmpty && !projects.containsKey(projectId)) {
          final rate = (entry['rate'] as num?)?.toDouble() ?? 0.0;
          final billing = entry['billing'] as String? ?? '';
          projects[projectId] = ProjectModel(
            id: projectId,
            name: projectName,
            categoryId: categoryId.isNotEmpty ? categoryId : null,
            colorValue: 0xFF6366F1,
            hourlyRate: rate,
            isBillable: billing != 'NON_BILLABLE',
            createdAt: DateTime.now(),
          );
        }

        // Extract task
        final taskId = entry['task_id'] as String? ?? '';
        final taskName = entry['task'] as String? ?? '';
        if (taskId.isNotEmpty && taskName.isNotEmpty && !tasks.containsKey(taskId)) {
          tasks[taskId] = TaskModel(
            id: taskId,
            projectId: projectId,
            name: taskName,
            isBillable: (entry['billing'] as String? ?? '') != 'NON_BILLABLE',
            createdAt: DateTime.now(),
          );
        }

        // Build time entry
        final entryId = entry['id'] as String? ?? const Uuid().v4();
        final dateStr = entry['date'] as String? ?? '';
        final durationMinutes = (entry['duration'] as num?)?.toInt() ?? 0;
        final note = entry['note'] as String? ?? '';

        DateTime startTime;
        try {
          startTime = DateTime.parse(dateStr);
        } catch (_) {
          continue; // Skip entries with invalid dates
        }

        final endTime = startTime.add(Duration(minutes: durationMinutes));

        timeEntries.add(TimeEntryModel(
          id: entryId,
          projectId: projectId,
          taskId: taskId,
          startTime: startTime,
          endTime: endTime,
          durationSeconds: durationMinutes * 60,
          notes: note,
          createdAt: DateTime.now(),
          isBillable: (entry['billing'] as String? ?? '') != 'NON_BILLABLE',
        ));
      }

      // Import in dependency order
      int catCount = 0, projCount = 0, taskCount = 0, entryCount = 0;

      for (final category in categories.values) {
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

      for (final project in projects.values) {
        if (mode == ImportMode.merge) {
          final existing = _projectRepository.getById(project.id);
          if (existing != null) {
            await _projectRepository.update(project.copyWith(
              colorValue: existing.colorValue,
              createdAt: existing.createdAt,
            ));
          } else {
            await _projectRepository.add(project);
          }
        } else {
          await _projectRepository.add(project);
        }
        projCount++;
      }

      for (final task in tasks.values) {
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

      return ImportResult(
        categoriesImported: catCount,
        projectsImported: projCount,
        tasksImported: taskCount,
        entriesImported: entryCount,
      );
    } catch (e) {
      debugPrint('Import error: $e');
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
