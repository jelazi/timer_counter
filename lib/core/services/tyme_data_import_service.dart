import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/category_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import 'tyme_import_service.dart';

/// Import service for Tyme app's native backup format (.data files).
/// These are SQLite/Core Data databases exported by the Tyme macOS/iOS app.
///
/// Database structure:
/// - ZADATA table: stores all entities (categories, projects, tasks) using Z_ENT discriminator
///   - Z_ENT=9: ProjectCategory
///   - Z_ENT=8: Project
///   - Z_ENT=6: TimedTask
/// - ZATASKRECORD table: stores time records
///   - Z_ENT=14: TimedTaskRecord
/// - Timestamps are Core Data format: seconds since 2001-01-01 00:00:00 UTC
class TymeDataImportService {
  final TimeEntryRepository _timeEntryRepository;
  final ProjectRepository _projectRepository;
  final TaskRepository _taskRepository;
  final CategoryRepository _categoryRepository;

  // Core Data epoch offset: seconds between Unix epoch (1970-01-01) and Core Data epoch (2001-01-01)
  static const int _coreDataEpochOffset = 978307200;

  // Entity type discriminators from Z_PRIMARYKEY table
  static const int _entProjectCategory = 9;
  static const int _entProject = 8;
  static const int _entTimedTask = 6;
  static const int _entTimedTaskRecord = 14;

  TymeDataImportService({
    required TimeEntryRepository timeEntryRepository,
    required ProjectRepository projectRepository,
    required TaskRepository taskRepository,
    required CategoryRepository categoryRepository,
  }) : _timeEntryRepository = timeEntryRepository,
       _projectRepository = projectRepository,
       _taskRepository = taskRepository,
       _categoryRepository = categoryRepository;

  /// Import from a Tyme .data (SQLite) file.
  Future<ImportResult> importFromTymeData(String filePath, ImportMode mode) async {
    Database? db;
    try {
      db = sqlite3.open(filePath);

      // If overwrite mode, clear all existing data first
      if (mode == ImportMode.overwrite) {
        await _clearAllData();
      }

      final existingCategories = _categoryRepository.getAll();
      final existingProjects = _projectRepository.getAll();
      final existingTasks = _taskRepository.getAll();

      // ── Read Categories (Z_ENT=9) ──
      final Map<int, String> pkToCategoryId = {};
      int catCount = 0;

      final catRows = db.select('SELECT Z_PK, ZNAME, ZUNIQUEID, ZCOLOR FROM ZADATA WHERE Z_ENT = ?', [_entProjectCategory]);

      for (final row in catRows) {
        final pk = row['Z_PK'] as int;
        final name = row['ZNAME'] as String? ?? 'Unnamed Category';
        final uniqueId = row['ZUNIQUEID'] as String? ?? const Uuid().v4();
        final color = row['ZCOLOR'] as int? ?? 0xFF6366F1;

        // Check for existing category by name
        final existing = existingCategories.where((c) => c.name.toLowerCase() == name.toLowerCase()).toList();

        String categoryId;
        if (existing.isNotEmpty && mode == ImportMode.merge) {
          categoryId = existing.first.id;
        } else if (existing.isNotEmpty && mode == ImportMode.append) {
          categoryId = existing.first.id;
        } else {
          categoryId = uniqueId;
          final model = CategoryModel(id: categoryId, name: name, colorValue: _convertColor(color), createdAt: DateTime.now());

          if (mode == ImportMode.merge) {
            final existingById = _categoryRepository.getById(categoryId);
            if (existingById != null) {
              await _categoryRepository.update(model.copyWith(createdAt: existingById.createdAt));
            } else {
              await _categoryRepository.add(model);
            }
          } else {
            await _categoryRepository.add(model);
          }
          catCount++;
        }

        pkToCategoryId[pk] = categoryId;
      }

      // ── Read Projects (Z_ENT=8) ──
      final Map<int, String> pkToProjectId = {};
      int projCount = 0;

      final projRows = db.select(
        'SELECT Z_PK, ZNAME, ZUNIQUEID, ZRELATEDCATEGORY, ZCOLOR, ZHOURLYRATE, '
        'ZSTARTDATE, ZDUEDATE, ZPLANNEDDURATION, ZPLANNEDBUDGET, ZNOTE, ZBILLABLE '
        'FROM ZADATA WHERE Z_ENT = ?',
        [_entProject],
      );

      for (final row in projRows) {
        final pk = row['Z_PK'] as int;
        final name = row['ZNAME'] as String? ?? 'Unnamed Project';
        final uniqueId = row['ZUNIQUEID'] as String? ?? const Uuid().v4();
        final relatedCategoryPk = row['ZRELATEDCATEGORY'] as int?;
        final color = row['ZCOLOR'] as int? ?? 0xFF6366F1;
        final hourlyRate = (row['ZHOURLYRATE'] as num?)?.toDouble() ?? 0.0;
        final startDateTs = row['ZSTARTDATE'] as num?;
        final dueDateTs = row['ZDUEDATE'] as num?;
        final plannedDuration = (row['ZPLANNEDDURATION'] as num?)?.toDouble() ?? 0.0;
        final plannedBudget = (row['ZPLANNEDBUDGET'] as num?)?.toDouble() ?? 0.0;
        final note = row['ZNOTE'] as String? ?? '';
        final billable = row['ZBILLABLE'] as int?;

        final categoryId = relatedCategoryPk != null ? pkToCategoryId[relatedCategoryPk] : null;

        // Check for existing project by name
        final existing = existingProjects.where((p) => p.name.toLowerCase() == name.toLowerCase()).toList();

        String projectId;
        if (existing.isNotEmpty && mode == ImportMode.merge) {
          projectId = existing.first.id;
        } else if (existing.isNotEmpty && mode == ImportMode.append) {
          projectId = existing.first.id;
        } else {
          projectId = uniqueId;
          final model = ProjectModel(
            id: projectId,
            name: name,
            categoryId: categoryId,
            colorValue: _convertColor(color),
            hourlyRate: hourlyRate,
            plannedTimeHours: plannedDuration / 3600.0, // Duration is in seconds
            plannedBudget: plannedBudget,
            startDate: startDateTs != null ? _coreDataToDateTime(startDateTs.toDouble()) : null,
            dueDate: dueDateTs != null ? _coreDataToDateTime(dueDateTs.toDouble()) : null,
            notes: note,
            isArchived: false,
            isBillable: billable != 0,
            createdAt: DateTime.now(),
          );

          if (mode == ImportMode.merge) {
            final existingById = _projectRepository.getById(projectId);
            if (existingById != null) {
              await _projectRepository.update(model.copyWith(createdAt: existingById.createdAt));
            } else {
              await _projectRepository.add(model);
            }
          } else {
            await _projectRepository.add(model);
          }
          projCount++;
        }

        pkToProjectId[pk] = projectId;
      }

      // ── Read Tasks (Z_ENT=6: TimedTask) ──
      final Map<int, String> pkToTaskId = {};
      int taskCount = 0;

      final taskRows = db.select(
        'SELECT Z_PK, ZNAME, ZUNIQUEID, ZRELATEDPROJECT, ZHOURLYRATE, '
        'ZBILLABLE, ZNOTE, ZCOLOR '
        'FROM ZADATA WHERE Z_ENT = ?',
        [_entTimedTask],
      );

      for (final row in taskRows) {
        final pk = row['Z_PK'] as int;
        final name = row['ZNAME'] as String? ?? 'Unnamed Task';
        final uniqueId = row['ZUNIQUEID'] as String? ?? const Uuid().v4();
        final relatedProjectPk = row['ZRELATEDPROJECT'] as int?;
        final hourlyRate = (row['ZHOURLYRATE'] as num?)?.toDouble();
        final billable = row['ZBILLABLE'] as int?;
        final note = row['ZNOTE'] as String? ?? '';
        final color = row['ZCOLOR'] as int?;

        final projectId = relatedProjectPk != null ? pkToProjectId[relatedProjectPk] : null;
        if (projectId == null) {
          debugPrint('TymeDataImport: Skipping task "$name" — no matching project (PK=$relatedProjectPk)');
          continue;
        }

        // Check for existing task by name + project
        final existing = existingTasks.where((t) => t.name.toLowerCase() == name.toLowerCase() && t.projectId == projectId).toList();

        String taskId;
        if (existing.isNotEmpty && mode == ImportMode.merge) {
          taskId = existing.first.id;
        } else if (existing.isNotEmpty && mode == ImportMode.append) {
          taskId = existing.first.id;
        } else {
          taskId = uniqueId;
          final model = TaskModel(
            id: taskId,
            projectId: projectId,
            name: name,
            hourlyRate: hourlyRate,
            isBillable: billable != 0,
            notes: note,
            isArchived: false,
            createdAt: DateTime.now(),
            colorValue: color != null ? _convertColor(color) : 0xFF6366F1,
          );

          if (mode == ImportMode.merge) {
            final existingById = _taskRepository.getById(taskId);
            if (existingById != null) {
              await _taskRepository.update(model.copyWith(createdAt: existingById.createdAt));
            } else {
              await _taskRepository.add(model);
            }
          } else {
            await _taskRepository.add(model);
          }
          taskCount++;
        }

        pkToTaskId[pk] = taskId;
      }

      // ── Read Time Records (Z_ENT=14: TimedTaskRecord) ──
      int entryCount = 0;

      final recordRows = db.select(
        'SELECT Z_PK, ZUNIQUEID, ZRELATEDTASK, ZTIMESTART, ZTIMEEND, '
        'ZNOTE, ZBILLINGSTATE '
        'FROM ZATASKRECORD WHERE Z_ENT = ?',
        [_entTimedTaskRecord],
      );

      for (final row in recordRows) {
        final uniqueId = row['ZUNIQUEID'] as String? ?? const Uuid().v4();
        final relatedTaskPk = row['ZRELATEDTASK'] as int?;
        final timeStartTs = row['ZTIMESTART'] as num?;
        final timeEndTs = row['ZTIMEEND'] as num?;
        final note = row['ZNOTE'] as String? ?? '';
        final billingState = row['ZBILLINGSTATE'] as int? ?? 0;

        if (timeStartTs == null || timeEndTs == null) {
          debugPrint('TymeDataImport: Skipping record — missing start/end time');
          continue;
        }

        final taskId = relatedTaskPk != null ? pkToTaskId[relatedTaskPk] : null;
        if (taskId == null) {
          debugPrint('TymeDataImport: Skipping record — no matching task (PK=$relatedTaskPk)');
          continue;
        }

        // Look up the projectId for this task
        String? projectId;
        // Find which project this task belongs to by checking taskRows or repo
        final taskModel = _taskRepository.getById(taskId);
        projectId = taskModel?.projectId ?? '';

        final startTime = _coreDataToDateTime(timeStartTs.toDouble());
        final endTime = _coreDataToDateTime(timeEndTs.toDouble());
        final durationSeconds = endTime.difference(startTime).inSeconds;

        if (durationSeconds <= 0) {
          debugPrint('TymeDataImport: Skipping record — zero or negative duration');
          continue;
        }

        final entry = TimeEntryModel(
          id: uniqueId,
          projectId: projectId,
          taskId: taskId,
          startTime: startTime,
          endTime: endTime,
          durationSeconds: durationSeconds,
          notes: note,
          createdAt: DateTime.now(),
          isBillable: billingState == 0, // 0 = billable in Tyme
        );

        if (mode == ImportMode.merge) {
          final existing = _timeEntryRepository.getById(uniqueId);
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

      db.close();

      return ImportResult(categoriesImported: catCount, projectsImported: projCount, tasksImported: taskCount, entriesImported: entryCount);
    } catch (e) {
      db?.close();
      debugPrint('TymeDataImport error: $e');
      return ImportResult(error: e.toString());
    }
  }

  /// Convert Core Data timestamp (seconds since 2001-01-01) to DateTime.
  DateTime _coreDataToDateTime(double coreDataTimestamp) {
    final unixSeconds = coreDataTimestamp.toInt() + _coreDataEpochOffset;
    return DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true).toLocal();
  }

  /// Convert Tyme color int to ARGB color value.
  /// Tyme stores colors as integer values; we need to ensure alpha is 0xFF.
  int _convertColor(int tymeColor) {
    if (tymeColor <= 0) return 0xFF6366F1; // Default indigo
    // If it already has alpha channel set
    if (tymeColor > 0x00FFFFFF) return tymeColor;
    // Add full opacity alpha
    return 0xFF000000 | tymeColor;
  }

  Future<void> _clearAllData() async {
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
