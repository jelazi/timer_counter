import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/time_formatter.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../blocs/task/task_bloc.dart';
import '../blocs/task/task_event.dart';
import '../blocs/task/task_state.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TaskBloc>().add(LoadTasks(widget.project.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: kToolbarHeight + 28,
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: Color(widget.project.colorValue), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(widget.project.name),
          ],
        ),
        actions: [
          FilledButton.icon(onPressed: () => _showAddTaskDialog(context), icon: const Icon(Icons.add, size: 18), label: Text(tr('projects.add_task'))),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Info
            SizedBox(width: 300, child: _buildProjectInfo(context)),
            const SizedBox(width: 24),
            // Tasks
            Expanded(child: _buildTasksList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectInfo(BuildContext context) {
    final timeEntryRepo = context.read<TimeEntryRepository>();
    final totalSeconds = timeEntryRepo.getTotalDurationForProject(widget.project.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('projects.progress'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _InfoRow(label: tr('projects.tracked_time'), value: TimeFormatter.formatHumanReadable(totalSeconds)),
            if (widget.project.plannedTimeHours > 0) ...[
              const SizedBox(height: 8),
              _InfoRow(label: tr('projects.planned_time'), value: '${widget.project.plannedTimeHours}h'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (totalSeconds / 3600) / widget.project.plannedTimeHours,
                backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(Color(widget.project.colorValue)),
              ),
            ],
            if (widget.project.hourlyRate > 0) ...[
              const SizedBox(height: 12),
              _InfoRow(label: tr('projects.hourly_rate'), value: '${widget.project.hourlyRate.toStringAsFixed(0)} CZK/h'),
              const SizedBox(height: 8),
              _InfoRow(label: tr('statistics.revenue'), value: TimeFormatter.formatCurrency(TimeFormatter.calculateRevenue(totalSeconds, widget.project.hourlyRate), 'CZK')),
            ],
            if (widget.project.plannedBudget > 0) ...[
              const SizedBox(height: 8),
              _InfoRow(label: tr('projects.planned_budget'), value: TimeFormatter.formatCurrency(widget.project.plannedBudget, 'CZK')),
              const SizedBox(height: 8),
              _InfoRow(
                label: tr('projects.budget_remaining'),
                value: TimeFormatter.formatCurrency(widget.project.plannedBudget - TimeFormatter.calculateRevenue(totalSeconds, widget.project.hourlyRate), 'CZK'),
              ),
            ],
            if (widget.project.monthlyRequiredHours > 0) ...[
              const Divider(height: 24),
              Text(tr('projects.monthly_target'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              () {
                final now = DateTime.now();
                final monthStart = DateTime(now.year, now.month, 1);
                final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
                final monthEntries = timeEntryRepo.getByDateRange(monthStart, monthEnd);
                final monthSeconds = monthEntries.where((e) => e.projectId == widget.project.id).fold<int>(0, (sum, e) => sum + e.actualDurationSeconds);
                final monthHours = monthSeconds / 3600;
                final progress = monthHours / widget.project.monthlyRequiredHours;
                final remaining = widget.project.monthlyRequiredHours - monthHours;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(label: tr('projects.monthly_required_hours'), value: '${widget.project.monthlyRequiredHours.toStringAsFixed(1)}h'),
                    const SizedBox(height: 4),
                    _InfoRow(label: tr('projects.monthly_worked'), value: '${monthHours.toStringAsFixed(1)}h'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(progress >= 1.0 ? Colors.green : Color(widget.project.colorValue)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      remaining > 0 ? tr('projects.monthly_remaining', args: ['${remaining.toStringAsFixed(1)}']) : tr('projects.monthly_completed'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: remaining > 0 ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6) : Colors.green,
                        fontWeight: remaining <= 0 ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                );
              }(),
            ],
            if (widget.project.startDate != null) ...[
              const SizedBox(height: 12),
              _InfoRow(label: tr('projects.start_date'), value: DateFormat('d.M.yyyy').format(widget.project.startDate!)),
            ],
            if (widget.project.dueDate != null) ...[
              const SizedBox(height: 8),
              _InfoRow(label: tr('projects.due_date'), value: DateFormat('d.M.yyyy').format(widget.project.dueDate!)),
            ],
            const SizedBox(height: 12),
            _InfoRow(label: tr('projects.billable'), value: widget.project.isBillable ? tr('common.yes') : tr('common.no')),
            if (widget.project.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(tr('projects.notes'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 4),
              Text(widget.project.notes, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTasksList(BuildContext context) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        if (state is TaskLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is TaskLoaded) {
          if (state.tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(tr('projects.no_tasks'), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: state.tasks.length,
            itemBuilder: (context, index) {
              final task = state.tasks[index];
              return _TaskListItem(
                task: task,
                project: widget.project,
                onDelete: () {
                  // Check if task has time entries
                  final timeEntryRepo = context.read<TimeEntryRepository>();
                  final taskEntries = timeEntryRepo.getByTask(task.id);
                  if (taskEntries.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('projects.cannot_delete_task_has_entries')), backgroundColor: Colors.orange));
                    return;
                  }
                  context.read<TaskBloc>().add(DeleteTask(taskId: task.id, projectId: widget.project.id));
                },
              );
            },
          );
        }

        return const SizedBox();
      },
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    bool isBillable = widget.project.isBillable;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('projects.add_task')),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: tr('projects.task_name')),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: tr('projects.notes')),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SwitchListTile(title: Text(tr('projects.billable')), value: isBillable, onChanged: (v) => setDialogState(() => isBillable = v), contentPadding: EdgeInsets.zero),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('common.cancel'))),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final task = TaskModel(
                    id: const Uuid().v4(),
                    projectId: widget.project.id,
                    name: nameController.text,
                    isBillable: isBillable,
                    notes: notesController.text,
                    createdAt: DateTime.now(),
                    colorValue: widget.project.colorValue,
                  );
                  context.read<TaskBloc>().add(AddTask(task));
                  Navigator.pop(dialogContext);
                }
              },
              child: Text(tr('common.save')),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _TaskListItem extends StatelessWidget {
  final TaskModel task;
  final ProjectModel project;
  final VoidCallback onDelete;

  const _TaskListItem({required this.task, required this.project, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final timeEntryRepo = context.read<TimeEntryRepository>();
    final totalSeconds = timeEntryRepo.getTotalDurationForTask(task.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(color: Color(task.colorValue), borderRadius: BorderRadius.circular(2)),
        ),
        title: Text(task.name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Row(
          children: [
            Icon(Icons.access_time, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text(TimeFormatter.formatHumanReadable(totalSeconds)),
            if (!task.isBillable) ...[
              const SizedBox(width: 12),
              Chip(
                label: Text(tr('projects.non_billable'), style: const TextStyle(fontSize: 10)),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: onDelete,
              tooltip: tr('common.delete'),
            ),
          ],
        ),
      ),
    );
  }
}
