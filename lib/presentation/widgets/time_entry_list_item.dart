import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/desktop_theme.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/utils/time_formatter.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';

class TimeEntryListItem extends StatelessWidget {
  final TimeEntryModel entry;
  final ProjectModel? project;
  final TaskModel? task;
  final bool showSeconds;
  final bool isLast;

  const TimeEntryListItem({super.key, required this.entry, this.project, this.task, this.showSeconds = true, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final projectColor = project != null ? Color(project!.colorValue) : Colors.grey;
    if (PlatformUtils.isDesktop) return _buildDesktopRow(context, projectColor);

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

  Widget _buildDesktopRow(BuildContext context, Color projectColor) {
    final mac = MacColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final range = '${DateFormat('HH:mm').format(entry.startTime)}${entry.endTime != null ? ' – ${DateFormat('HH:mm').format(entry.endTime!)}' : ''}';

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: mac.separator)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: projectColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(project?.name ?? 'Unknown', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (task != null) ...[const SizedBox(width: 6), Text(task!.name, style: textTheme.bodyMedium?.copyWith(color: mac.secondaryLabel))],
          if (entry.notes.isNotEmpty) ...[
            const SizedBox(width: 10),
            Icon(Icons.notes, size: 13, color: mac.tertiaryLabel),
            const SizedBox(width: 4),
            Expanded(
              child: Text(entry.notes, style: textTheme.bodySmall, overflow: TextOverflow.ellipsis),
            ),
          ] else
            const Spacer(),
          const SizedBox(width: 12),
          Text(range, style: textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 16),
          SizedBox(
            width: 64,
            child: Text(
              TimeFormatter.formatDuration(entry.actualDurationSeconds, showSeconds: showSeconds),
              textAlign: TextAlign.right,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Groups [TimeEntryListItem] rows into one rounded box on desktop; passthrough on mobile.
class TimeEntryGroup extends StatelessWidget {
  final Widget child;

  const TimeEntryGroup({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isDesktop) return child;
    final mac = MacColors.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: mac.groupFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: mac.groupBorder),
        ),
        child: child,
      ),
    );
  }
}
