import 'package:flutter/material.dart';

import '../../core/utils/time_formatter.dart';
import '../../data/models/project_model.dart';
import '../../data/models/running_timer_model.dart';
import '../../data/models/task_model.dart';

class TimerCard extends StatelessWidget {
  final RunningTimerModel timer;
  final ProjectModel? project;
  final TaskModel? task;
  final bool showSeconds;
  final VoidCallback onStop;

  const TimerCard({super.key, required this.timer, this.project, this.task, this.showSeconds = true, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final elapsed = timer.elapsedSeconds;
    final projectColor = project != null ? Color(project!.colorValue) : Colors.grey;

    return SizedBox(
      width: 280,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: projectColor, width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(height: 8),
                    Text(
                      TimeFormatter.formatDuration(elapsed, showSeconds: showSeconds),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontFeatures: [const FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: onStop,
                icon: const Icon(Icons.stop),
                style: IconButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
