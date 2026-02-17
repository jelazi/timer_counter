import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/utils/time_formatter.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';

class TimeEntryListItem extends StatelessWidget {
  final TimeEntryModel entry;
  final ProjectModel? project;
  final TaskModel? task;
  final bool showSeconds;

  const TimeEntryListItem({super.key, required this.entry, this.project, this.task, this.showSeconds = true});

  @override
  Widget build(BuildContext context) {
    final projectColor = project != null ? Color(project!.colorValue) : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(color: projectColor, borderRadius: BorderRadius.circular(2)),
        ),
        title: Row(
          children: [
            Text(project?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500)),
            if (task != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
              Text(task!.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              '${DateFormat('HH:mm').format(entry.startTime)}'
              '${entry.endTime != null ? ' - ${DateFormat('HH:mm').format(entry.endTime!)}' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
            if (entry.notes.isNotEmpty) ...[
              const SizedBox(width: 12),
              Icon(Icons.note, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  entry.notes,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        trailing: Text(
          TimeFormatter.formatDuration(entry.actualDurationSeconds, showSeconds: showSeconds),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontFeatures: [const FontFeature.tabularFigures()]),
        ),
      ),
    );
  }
}
