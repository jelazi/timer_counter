import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/time_formatter.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_state.dart';
import '../blocs/timer/timer_bloc.dart';
import '../blocs/timer/timer_event.dart';
import '../blocs/timer/timer_state.dart';
import '../widgets/time_entry_list_item.dart';

class TimeTrackingScreen extends StatefulWidget {
  const TimeTrackingScreen({super.key});

  @override
  State<TimeTrackingScreen> createState() => _TimeTrackingScreenState();
}

class _TimeTrackingScreenState extends State<TimeTrackingScreen> {
  ProjectModel? _selectedProject;
  TaskModel? _selectedTask;
  List<TaskModel> _tasks = [];
  bool _initialized = false;

  void _initSelection() {
    if (_initialized) return;
    _initialized = true;

    final settingsRepo = context.read<SettingsRepository>();
    final projectRepo = context.read<ProjectRepository>();
    final taskRepo = context.read<TaskRepository>();

    final lastProjectId = settingsRepo.getLastProjectId();
    final lastTaskId = settingsRepo.getLastTaskId();

    if (lastProjectId != null) {
      final project = projectRepo.getById(lastProjectId);
      if (project != null && !project.isArchived) {
        _selectedProject = project;
        _tasks = taskRepo.getByProject(project.id);
        if (lastTaskId != null && _tasks.isNotEmpty) {
          try {
            _selectedTask = _tasks.firstWhere((t) => t.id == lastTaskId);
          } catch (_) {
            _selectedTask = _tasks.first;
          }
        } else if (_tasks.isNotEmpty) {
          _selectedTask = _tasks.first;
        }
      }
    }

    if (_selectedProject == null) {
      final projects = projectRepo.getActive();
      if (projects.isNotEmpty) {
        _selectedProject = projects.first;
        _tasks = taskRepo.getByProject(projects.first.id);
        if (_tasks.isNotEmpty) _selectedTask = _tasks.first;
      }
    }
  }

  void _loadTasks(String projectId) {
    final taskRepo = context.read<TaskRepository>();
    setState(() {
      _tasks = taskRepo.getByProject(projectId);
      if (_selectedTask != null && !_tasks.any((t) => t.id == _selectedTask!.id)) {
        _selectedTask = _tasks.isNotEmpty ? _tasks.first : null;
      }
    });
  }

  void _startTimer() {
    if (_selectedProject == null || _selectedTask == null) return;
    final settingsRepo = context.read<SettingsRepository>();
    settingsRepo.setLastProjectId(_selectedProject!.id);
    settingsRepo.setLastTaskId(_selectedTask!.id);
    context.read<TimerBloc>().add(StartTimer(projectId: _selectedProject!.id, taskId: _selectedTask!.id));
  }

  void _stopTimer(String timerId) {
    context.read<TimerBloc>().add(StopTimer(timerId));
  }

  void _switchTimer() {
    if (_selectedProject == null || _selectedTask == null) return;
    final settingsRepo = context.read<SettingsRepository>();
    settingsRepo.setLastProjectId(_selectedProject!.id);
    settingsRepo.setLastTaskId(_selectedTask!.id);
    context.read<TimerBloc>().add(StartTimer(projectId: _selectedProject!.id, taskId: _selectedTask!.id));
  }

  _ButtonMode _getButtonMode(TimerRunning timerState) {
    if (timerState.runningTimers.isEmpty) return _ButtonMode.start;
    final runningTimer = timerState.runningTimers.first;
    if (_selectedProject?.id == runningTimer.projectId && _selectedTask?.id == runningTimer.taskId) {
      return _ButtonMode.stop;
    }
    return _ButtonMode.switchTimer;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimerBloc, TimerState>(
      builder: (context, timerState) {
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            if (timerState is TimerRunning) {
              _initSelection();
              return _buildContent(context, timerState, settingsState);
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, TimerRunning timerState, SettingsState settingsState) {
    final projects = context.read<ProjectRepository>().getActive();
    final buttonMode = _getButtonMode(timerState);
    final isRunning = timerState.runningTimers.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('time_tracking.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<ProjectModel>(
                        decoration: InputDecoration(
                          labelText: tr('time_tracking.select_project'),
                          prefixIcon: const Icon(Icons.folder_outlined),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        isExpanded: true,
                        value: _selectedProject,
                        items: projects.map((project) {
                          return DropdownMenuItem(
                            value: project,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
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
                          if (project != null) _loadTasks(project.id);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<TaskModel>(
                        decoration: InputDecoration(
                          labelText: tr('time_tracking.select_task'),
                          prefixIcon: const Icon(Icons.task_outlined),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        isExpanded: true,
                        value: _selectedTask,
                        items: _tasks.map((task) => DropdownMenuItem(value: task, child: Text(task.name))).toList(),
                        onChanged: (task) => setState(() => _selectedTask = task),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(height: 48, child: _buildActionButton(buttonMode, timerState)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isRunning) ...[_buildRunningTimerCard(context, timerState, settingsState), const SizedBox(height: 16)],
            _buildTotalTodayCard(context, timerState, settingsState),
            const SizedBox(height: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('time_tracking.today'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: timerState.todayEntries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer_off_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                Text(
                                  tr('time_tracking.no_entries_today'),
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: timerState.todayEntries.length,
                            itemBuilder: (context, index) {
                              final entry = timerState.todayEntries[index];
                              final projectRepo = context.read<ProjectRepository>();
                              final taskRepo = context.read<TaskRepository>();
                              final project = projectRepo.getById(entry.projectId);
                              final task = taskRepo.getById(entry.taskId);
                              return TimeEntryListItem(entry: entry, project: project, task: task, showSeconds: settingsState.showSeconds);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(_ButtonMode mode, TimerRunning timerState) {
    switch (mode) {
      case _ButtonMode.start:
        return FilledButton.icon(
          onPressed: (_selectedProject != null && _selectedTask != null) ? _startTimer : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(tr('time_tracking.start_timer')),
        );
      case _ButtonMode.stop:
        return FilledButton.icon(
          onPressed: () => _stopTimer(timerState.runningTimers.first.id),
          icon: const Icon(Icons.stop),
          label: Text(tr('time_tracking.stop_timer')),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
        );
      case _ButtonMode.switchTimer:
        return FilledButton.icon(
          onPressed: (_selectedProject != null && _selectedTask != null) ? _switchTimer : null,
          icon: const Icon(Icons.swap_horiz),
          label: Text(tr('time_tracking.switch_timer')),
          style: FilledButton.styleFrom(backgroundColor: Colors.orange),
        );
    }
  }

  Widget _buildRunningTimerCard(BuildContext context, TimerRunning timerState, SettingsState settingsState) {
    final timer = timerState.runningTimers.first;
    final projectRepo = context.read<ProjectRepository>();
    final taskRepo = context.read<TaskRepository>();
    final project = projectRepo.getById(timer.projectId);
    final task = taskRepo.getById(timer.taskId);
    final projectColor = project != null ? Color(project.colorValue) : Colors.grey;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: projectColor, width: 4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project?.name ?? 'Unknown Project',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task?.name ?? 'Unknown Task',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              TimeFormatter.formatDuration(timer.elapsedSeconds, showSeconds: settingsState.showSeconds),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontFeatures: [const FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 16),
            IconButton.filled(
              onPressed: () => _stopTimer(timer.id),
              icon: const Icon(Icons.stop),
              style: IconButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalTodayCard(BuildContext context, TimerRunning timerState, SettingsState settingsState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.today, color: Theme.of(context).colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('time_tracking.total_today'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 4),
                Text(
                  TimeFormatter.formatDuration(timerState.totalTodaySeconds, showSeconds: settingsState.showSeconds),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ButtonMode { start, stop, switchTimer }
