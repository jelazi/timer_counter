import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';

class StartTimerDialog extends StatefulWidget {
  final List<ProjectModel> projects;
  final Function(ProjectModel project, TaskModel task, String notes) onStart;

  const StartTimerDialog({super.key, required this.projects, required this.onStart});

  @override
  State<StartTimerDialog> createState() => _StartTimerDialogState();
}

class _StartTimerDialogState extends State<StartTimerDialog> {
  ProjectModel? _selectedProject;
  TaskModel? _selectedTask;
  final _notesController = TextEditingController();
  List<TaskModel> _tasks = [];

  @override
  void initState() {
    super.initState();
    _restoreLastSelection();
  }

  void _restoreLastSelection() {
    final settingsRepo = context.read<SettingsRepository>();
    final lastProjectId = settingsRepo.getLastProjectId();
    final lastTaskId = settingsRepo.getLastTaskId();

    if (lastProjectId != null) {
      try {
        final project = widget.projects.firstWhere((p) => p.id == lastProjectId);
        _selectedProject = project;
        _loadTasks(project.id);

        if (lastTaskId != null && _tasks.isNotEmpty) {
          try {
            _selectedTask = _tasks.firstWhere((t) => t.id == lastTaskId);
          } catch (_) {
            // Task no longer exists, ignore
          }
        }
      } catch (_) {
        // Project no longer exists, ignore
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _loadTasks(String projectId) {
    final taskRepo = context.read<TaskRepository>();
    setState(() {
      _tasks = taskRepo.getByProject(projectId);
      if (_selectedTask != null && !_tasks.any((t) => t.id == _selectedTask!.id)) {
        _selectedTask = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('time_tracking.start_timer')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Selection
            DropdownButtonFormField<ProjectModel>(
              decoration: InputDecoration(labelText: tr('time_tracking.select_project'), prefixIcon: const Icon(Icons.folder_outlined)),
              isExpanded: true,
              initialValue: _selectedProject,
              items: widget.projects.map((project) {
                return DropdownMenuItem(
                  value: project,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: Color(project.colorValue), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(project.name, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (project) {
                setState(() => _selectedProject = project);
                if (project != null) {
                  _loadTasks(project.id);
                }
              },
            ),
            const SizedBox(height: 16),

            // Task Selection
            DropdownButtonFormField<TaskModel>(
              decoration: InputDecoration(labelText: tr('time_tracking.select_task'), prefixIcon: const Icon(Icons.task_outlined)),
              isExpanded: true,
              items: _tasks.map((task) {
                return DropdownMenuItem(value: task, child: Text(task.name));
              }).toList(),
              onChanged: (task) {
                setState(() => _selectedTask = task);
              },
              initialValue: _selectedTask,
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: tr('time_tracking.notes'), prefixIcon: const Icon(Icons.notes)),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
        FilledButton.icon(
          onPressed: _selectedProject != null && _selectedTask != null
              ? () {
                  // Save last selection
                  final settingsRepo = context.read<SettingsRepository>();
                  settingsRepo.setLastProjectId(_selectedProject!.id);
                  settingsRepo.setLastTaskId(_selectedTask!.id);

                  widget.onStart(_selectedProject!, _selectedTask!, _notesController.text);
                  Navigator.pop(context);
                }
              : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(tr('time_tracking.start_timer')),
        ),
      ],
    );
  }
}
