import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/pocketbase_sync_service.dart';
import '../../core/utils/time_formatter.dart';
import '../../data/models/project_model.dart';
import '../../data/models/running_timer_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/time_entry_model.dart';
import '../../data/repositories/monthly_hours_target_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_state.dart';
import '../blocs/timer/timer_bloc.dart';
import '../blocs/timer/timer_event.dart';
import '../blocs/timer/timer_state.dart';

class TimeEntriesOverviewScreen extends StatefulWidget {
  const TimeEntriesOverviewScreen({super.key});

  @override
  State<TimeEntriesOverviewScreen> createState() => _TimeEntriesOverviewScreenState();
}

class _TimeEntriesOverviewScreenState extends State<TimeEntriesOverviewScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  DateTime get _monthStart => _selectedMonth;
  DateTime get _monthEnd {
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    return nextMonth.subtract(const Duration(seconds: 1));
  }

  /// Get running timers whose startTime falls within the given date range.
  List<RunningTimerModel> _getRunningTimersInRange(TimerState timerState, DateTime startDate, DateTime endDate) {
    if (timerState is TimerRunning) {
      return timerState.runningTimers.where((t) => !t.startTime.isBefore(startDate) && t.startTime.isBefore(endDate)).toList();
    }
    return [];
  }

  /// Calculate running timer seconds per project within the date range.
  Map<String, int> _runningSecondsPerProject(TimerState timerState, DateTime startDate, DateTime endDate) {
    final map = <String, int>{};
    for (final t in _getRunningTimersInRange(timerState, startDate, endDate)) {
      map[t.projectId] = (map[t.projectId] ?? 0) + t.elapsedSeconds;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TimerBloc, TimerState>(
      builder: (context, timerState) {
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            final isMobile = MediaQuery.of(context).size.width < 600;
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            tr('time_entries.title'),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _showAddManualEntryDialog(context, settingsState),
                          icon: const Icon(Icons.add),
                          label: Text(tr('time_entries.add_manual')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Month navigation
                    _buildMonthNavigator(context),
                    const SizedBox(height: 16),

                    // Entries list grouped by day
                    Expanded(child: _buildMonthlyView(context, settingsState)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMonthNavigator(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
            });
          },
        ),
        Flexible(
          child: TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
              }
            },
            child: Text(
              DateFormat('LLLL yyyy', context.locale.languageCode).format(_selectedMonth),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
            });
          },
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            final now = DateTime.now();
            setState(() => _selectedMonth = DateTime(now.year, now.month, 1));
          },
          child: Text(tr('time_tracking.this_month')),
        ),
      ],
    );
  }

  Widget _buildMonthlyView(BuildContext context, SettingsState settingsState) {
    final timeEntryRepo = context.read<TimeEntryRepository>();
    final projectRepo = context.read<ProjectRepository>();
    final taskRepo = context.read<TaskRepository>();
    final isMobile = MediaQuery.of(context).size.width < 600;

    final entries = timeEntryRepo.getByDateRange(_monthStart, _monthEnd.add(const Duration(seconds: 1)));

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              tr('time_entries.no_entries_month'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    // Group by day
    final grouped = <DateTime, List<TimeEntryModel>>{};
    for (final entry in entries) {
      final dayKey = DateTime(entry.startTime.year, entry.startTime.month, entry.startTime.day);
      grouped.putIfAbsent(dayKey, () => []).add(entry);
    }

    // Sort days descending (newest first)
    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    // Month total (including running timers)
    final timerState = context.read<TimerBloc>().state;
    final runningTimersInMonth = _getRunningTimersInRange(timerState, _monthStart, _monthEnd.add(const Duration(seconds: 1)));
    final runningSecondsMonth = runningTimersInMonth.fold(0, (sum, t) => sum + t.elapsedSeconds);
    final totalSeconds = entries.fold(0, (sum, e) => sum + e.actualDurationSeconds) + runningSecondsMonth;

    final summaryWidgets = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month total card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${tr('time_entries.month_total')}: ${TimeFormatter.formatDuration(totalSeconds, showSeconds: false)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${entries.length} ${tr('time_entries.entries_count')}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Monthly targets progress
        _buildMonthlyTargetsProgress(context, entries, projectRepo),
      ],
    );

    if (isMobile) {
      // On mobile, summary cards scroll with the day sections
      return ListView.builder(
        itemCount: sortedDays.length + 1, // +1 for summary header
        itemBuilder: (context, index) {
          if (index == 0) return summaryWidgets;
          final dayIndex = index - 1;
          final day = sortedDays[dayIndex];
          final dayEntries = grouped[day]!..sort((a, b) => b.startTime.compareTo(a.startTime));
          return _buildDaySection(context, day, dayEntries, projectRepo, taskRepo, settingsState);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        summaryWidgets,
        Expanded(
          child: ListView.builder(
            itemCount: sortedDays.length,
            itemBuilder: (context, index) {
              final day = sortedDays[index];
              final dayEntries = grouped[day]!..sort((a, b) => b.startTime.compareTo(a.startTime));
              return _buildDaySection(context, day, dayEntries, projectRepo, taskRepo, settingsState);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyTargetsProgress(BuildContext context, List<TimeEntryModel> monthEntries, ProjectRepository projectRepo) {
    final targetRepo = context.read<MonthlyHoursTargetRepository>();
    final settingsRepo = context.read<SettingsRepository>();
    final targets = targetRepo.getAll();
    if (targets.isEmpty) return const SizedBox.shrink();

    // Calculate hours per project for the current month
    final hoursPerProject = <String, double>{};
    for (final entry in monthEntries) {
      hoursPerProject.update(entry.projectId, (val) => val + entry.actualDurationSeconds / 3600.0, ifAbsent: () => entry.actualDurationSeconds / 3600.0);
    }

    // Include running timer seconds per project
    final timerState = context.read<TimerBloc>().state;
    final runningPerProject = _runningSecondsPerProject(timerState, _monthStart, _monthEnd.add(const Duration(seconds: 1)));
    for (final entry in runningPerProject.entries) {
      hoursPerProject.update(entry.key, (val) => val + entry.value / 3600.0, ifAbsent: () => entry.value / 3600.0);
    }

    // Calculate remaining working days in current month
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    // Check if today is a working day and already has entries
    final todayIsWorkDay = settingsRepo.getExpectedHoursForDay(today.weekday) > 0;
    final hasTodayEntries =
        monthEntries.any((e) {
          final entryDay = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
          return entryDay == today;
        }) ||
        _getRunningTimersInRange(timerState, today, today.add(const Duration(days: 1))).isNotEmpty;
    // If today is a work day and already has work done, skip it (start from tomorrow)
    final countFrom = (todayIsWorkDay && hasTodayEntries) ? today.add(const Duration(days: 1)) : today;
    int remainingWorkDays = 0;
    for (DateTime d = countFrom; !d.isAfter(lastDayOfMonth); d = d.add(const Duration(days: 1))) {
      if (settingsRepo.getExpectedHoursForDay(d.weekday) > 0) {
        remainingWorkDays++;
      }
    }

    return Column(
      children: [
        ...targets.map((target) {
          final workedHours = target.projectIds.fold(0.0, (sum, pid) => sum + (hoursPerProject[pid] ?? 0));
          final progress = target.targetHours > 0 ? (workedHours / target.targetHours).clamp(0.0, 1.0) : 0.0;
          final isComplete = workedHours >= target.targetHours;
          final remainingHours = (target.targetHours - workedHours).clamp(0.0, double.infinity);
          final dailyNeeded = remainingWorkDays > 0 && !isComplete ? remainingHours / remainingWorkDays : 0.0;
          final projectNames = target.projectIds
              .map((id) {
                final p = projectRepo.getById(id);
                return p?.name ?? '';
              })
              .where((n) => n.isNotEmpty)
              .join(', ');

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isComplete ? Icons.check_circle : Icons.track_changes, color: isComplete ? Colors.green : Theme.of(context).colorScheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(target.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        '${workedHours.toStringAsFixed(1)}h / ${target.targetHours.toStringAsFixed(0)}h',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: isComplete ? Colors.green : null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      color: isComplete ? Colors.green : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          projectNames,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isComplete && remainingWorkDays > 0)
                        Text(
                          tr('monthly_targets.daily_needed', namedArgs: {'hours': dailyNeeded.toStringAsFixed(1), 'days': '$remainingWorkDays'}),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildDaySection(BuildContext context, DateTime day, List<TimeEntryModel> entries, ProjectRepository projectRepo, TaskRepository taskRepo, SettingsState settingsState) {
    final settingsRepo = context.read<SettingsRepository>();
    final dayTotal = entries.fold(0, (sum, e) => sum + e.actualDurationSeconds);
    final isToday = _isToday(day);

    // Include running timer seconds for today
    final timerState = context.read<TimerBloc>().state;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final runningDaySeconds = isToday ? _getRunningTimersInRange(timerState, dayStart, dayEnd).fold(0, (sum, t) => sum + t.elapsedSeconds) : 0;
    final dayTotalWithRunning = dayTotal + runningDaySeconds;

    // Calculate daily deficit/surplus based on expected hours for this day
    final expectedDayHours = settingsRepo.getExpectedHoursForDay(day.weekday);
    final workedDayHours = dayTotalWithRunning / 3600.0;
    final dayDiff = workedDayHours - expectedDayHours; // positive = surplus, negative = deficit
    final hasDayExpectation = expectedDayHours > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isToday ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      tr('time_tracking.today'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                Flexible(
                  child: Text(
                    DateFormat("EEEE, d'.' MMMM", context.locale.languageCode).format(day),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entries.length} \u2014 ${TimeFormatter.formatDuration(dayTotalWithRunning, showSeconds: false)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (hasDayExpectation) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: dayDiff >= 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${dayDiff >= 0 ? "+" : ""}${dayDiff.toStringAsFixed(1)}h',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: dayDiff >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Timeline bar
          _buildTimelineBar(context, entries, projectRepo),

          const Divider(height: 1),

          // Entries
          ...entries.map((entry) {
            final project = projectRepo.getById(entry.projectId);
            final task = taskRepo.getById(entry.taskId);
            return _buildEntryTile(context, entry, project, task, settingsState);
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineBar(BuildContext context, List<TimeEntryModel> entries, ProjectRepository projectRepo) {
    final settingsRepo = context.read<SettingsRepository>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hour labels
          Row(
            children: [
              for (int h = 0; h <= 24; h += 3)
                Expanded(
                  child: Text(
                    h.toString().padLeft(2, '0'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 9),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          // Timeline bar
          SizedBox(
            height: 20,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                const totalMinutes = 24 * 60;

                // Determine work schedule for the day
                int? dayWeekday;
                if (entries.isNotEmpty) {
                  dayWeekday = entries.first.startTime.weekday;
                }

                return Stack(
                  children: [
                    // Background
                    Container(
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4)),
                    ),
                    // Work schedule overlay
                    if (dayWeekday != null && settingsRepo.getWorkScheduleEnabled(dayWeekday)) ...[
                      () {
                        final startStr = settingsRepo.getWorkScheduleStart(dayWeekday!);
                        final endStr = settingsRepo.getWorkScheduleEnd(dayWeekday);
                        final startParts = startStr.split(':');
                        final endParts = endStr.split(':');
                        final workStart = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
                        final workEnd = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
                        final left = (workStart / totalMinutes) * totalWidth;
                        final width = ((workEnd - workStart) / totalMinutes) * totalWidth;
                        return Positioned(
                          left: left.clamp(0, totalWidth),
                          width: width.clamp(0, totalWidth - left.clamp(0, totalWidth)),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), width: 1),
                            ),
                          ),
                        );
                      }(),
                    ],
                    // Entry segments
                    ...entries.map((entry) {
                      final project = projectRepo.getById(entry.projectId);
                      final startMinutes = entry.startTime.hour * 60 + entry.startTime.minute;
                      final endMinutes = entry.endTime != null ? entry.endTime!.hour * 60 + entry.endTime!.minute : startMinutes + (entry.durationSeconds ~/ 60);
                      final left = (startMinutes / totalMinutes) * totalWidth;
                      final width = ((endMinutes - startMinutes) / totalMinutes) * totalWidth;

                      return Positioned(
                        left: left.clamp(0, totalWidth),
                        width: width.clamp(2, totalWidth - left.clamp(0, totalWidth)),
                        top: 2,
                        bottom: 2,
                        child: Tooltip(
                          message:
                              '${project?.name ?? "?"} \u2014 ${DateFormat('HH:mm').format(entry.startTime)}-${entry.endTime != null ? DateFormat('HH:mm').format(entry.endTime!) : '...'}',
                          child: Container(
                            decoration: BoxDecoration(
                              color: project != null ? Color(project.colorValue) : Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  Widget _buildEntryTile(BuildContext context, TimeEntryModel entry, ProjectModel? project, TaskModel? task, SettingsState settingsState) {
    final timeFormat = DateFormat('HH:mm');
    final startStr = timeFormat.format(entry.startTime);
    final endStr = entry.endTime != null ? timeFormat.format(entry.endTime!) : '...';
    final duration = TimeFormatter.formatDuration(entry.actualDurationSeconds, showSeconds: settingsState.showSeconds);

    return ListTile(
      dense: true,
      leading: Container(
        width: 4,
        height: 32,
        decoration: BoxDecoration(color: project != null ? Color(project.colorValue) : Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2)),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              project?.name ?? 'Unknown',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text('/ ${task?.name ?? 'Unknown'}', style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      subtitle: entry.notes.isNotEmpty ? Text(entry.notes, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text('$startStr - $endStr', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Text(duration, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                onPressed: () => _editEntry(context, entry, settingsState),
                tooltip: tr('common.edit'),
                padding: EdgeInsets.zero,
                iconSize: 16,
              ),
            ),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                onPressed: () => _deleteEntry(context, entry),
                tooltip: tr('common.delete'),
                padding: EdgeInsets.zero,
                iconSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEntry(BuildContext context, TimeEntryModel entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('time_tracking.delete_entry')),
        content: Text(tr('time_tracking.delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('common.delete'))),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<TimeEntryRepository>().delete(entry.id);
    if (!context.mounted) return;
    context.read<PocketBaseSyncService?>()?.deleteTimeEntry(entry.id);
    context.read<TimerBloc>().add(const LoadRunningTimers());
    setState(() {});

    // Show SnackBar with undo
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('time_tracking.entry_deleted')),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: tr('common.undo'),
          onPressed: () async {
            await context.read<TimeEntryRepository>().add(entry);
            if (!context.mounted) return;
            context.read<PocketBaseSyncService?>()?.pushTimeEntry(entry);
            context.read<TimerBloc>().add(const LoadRunningTimers());
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('time_tracking.entry_restored')), backgroundColor: Colors.green));
            setState(() {});
          },
        ),
      ),
    );
  }

  void _editEntry(BuildContext context, TimeEntryModel entry, SettingsState settingsState) {
    final projects = context.read<ProjectRepository>().getActive();
    if (projects.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => _EditEntryDialog(
        entry: entry,
        projects: projects,
        allowOverlap: settingsState.allowOverlapTimes,
        onSave: (updatedEntry) async {
          final timeEntryRepo = context.read<TimeEntryRepository>();
          await timeEntryRepo.update(updatedEntry);
          if (context.mounted) {
            context.read<PocketBaseSyncService?>()?.pushTimeEntry(updatedEntry);
            context.read<TimerBloc>().add(const LoadRunningTimers());
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('time_entries.entry_updated'))));
            setState(() {});
          }
        },
      ),
    );
  }

  void _showAddManualEntryDialog(BuildContext context, SettingsState settingsState) {
    final projects = context.read<ProjectRepository>().getActive();
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('projects.no_projects'))));
      return;
    }

    showDialog(
      context: context,
      builder: (_) => _AddManualEntryDialog(
        projects: projects,
        initialDate: DateTime.now(),
        allowOverlap: settingsState.allowOverlapTimes,
        onSave: (entry) async {
          final timeEntryRepo = context.read<TimeEntryRepository>();
          await timeEntryRepo.add(entry);
          if (context.mounted) {
            context.read<PocketBaseSyncService?>()?.pushTimeEntry(entry);
            context.read<TimerBloc>().add(const LoadRunningTimers());
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('time_entries.manual_entry_saved'))));
            setState(() {});
          }
        },
      ),
    );
  }
}

// ---- Add Manual Entry Dialog ----

class _AddManualEntryDialog extends StatefulWidget {
  final List<ProjectModel> projects;
  final DateTime initialDate;
  final bool allowOverlap;
  final Function(TimeEntryModel entry) onSave;

  const _AddManualEntryDialog({required this.projects, required this.initialDate, required this.allowOverlap, required this.onSave});

  @override
  State<_AddManualEntryDialog> createState() => _AddManualEntryDialogState();
}

class _AddManualEntryDialogState extends State<_AddManualEntryDialog> {
  ProjectModel? _selectedProject;
  TaskModel? _selectedTask;
  List<TaskModel> _tasks = [];
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  final _notesController = TextEditingController();
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  bool _isBillable = true;
  String? _overlapError;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _startTimeController = TextEditingController(text: _formatTimeOfDay(_startTime));
    _endTimeController = TextEditingController(text: _formatTimeOfDay(_endTime));
    _restoreLastSelection();
  }

  String _formatTimeOfDay(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay? _parseTime(String text) {
    final parts = text.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
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
          } catch (_) {}
        }
      } catch (_) {}
    }
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
  void dispose() {
    _notesController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('time_entries.add_manual')),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project
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
                if (project != null) _loadTasks(project.id);
              },
            ),
            const SizedBox(height: 12),

            // Task
            DropdownButtonFormField<TaskModel>(
              decoration: InputDecoration(labelText: tr('time_tracking.select_task'), prefixIcon: const Icon(Icons.task_outlined)),
              isExpanded: true,
              initialValue: _selectedTask,
              items: _tasks.map((task) => DropdownMenuItem(value: task, child: Text(task.name))).toList(),
              onChanged: (task) => setState(() => _selectedTask = task),
            ),
            const SizedBox(height: 16),

            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(tr('time_entries.date')),
              subtitle: Text(DateFormat('EEEE, d MMMM yyyy', context.locale.languageCode).format(_selectedDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
            ),
            const SizedBox(height: 8),

            // Time inputs (manual text + picker icon)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startTimeController,
                    decoration: InputDecoration(
                      labelText: tr('time_entries.start'),
                      hintText: 'HH:mm',
                      prefixIcon: const Icon(Icons.play_arrow),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.access_time),
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: _startTime);
                          if (picked != null) {
                            setState(() {
                              _startTime = picked;
                              _startTimeController.text = _formatTimeOfDay(picked);
                              _overlapError = null;
                            });
                          }
                        },
                      ),
                    ),
                    onChanged: (text) {
                      final parsed = _parseTime(text);
                      if (parsed != null) {
                        setState(() {
                          _startTime = parsed;
                          _overlapError = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _endTimeController,
                    decoration: InputDecoration(
                      labelText: tr('time_entries.end'),
                      hintText: 'HH:mm',
                      prefixIcon: const Icon(Icons.stop),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.access_time),
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: _endTime);
                          if (picked != null) {
                            setState(() {
                              _endTime = picked;
                              _endTimeController.text = _formatTimeOfDay(picked);
                              _overlapError = null;
                            });
                          }
                        },
                      ),
                    ),
                    onChanged: (text) {
                      final parsed = _parseTime(text);
                      if (parsed != null) {
                        setState(() {
                          _endTime = parsed;
                          _overlapError = null;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Duration preview
            _buildDurationPreview(context),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: tr('time_tracking.notes'), prefixIcon: const Icon(Icons.notes)),
              maxLines: 2,
            ),
            const SizedBox(height: 8),

            // Billable toggle
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr('projects.billable')), value: _isBillable, onChanged: (v) => setState(() => _isBillable = v)),

            // Overlap error
            if (_overlapError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_overlapError!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
        FilledButton.icon(
          onPressed: _selectedProject != null && _selectedTask != null && _isValidTimeRange()
              ? () {
                  final settingsRepo = context.read<SettingsRepository>();
                  settingsRepo.setLastProjectId(_selectedProject!.id);
                  settingsRepo.setLastTaskId(_selectedTask!.id);

                  final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime.hour, _startTime.minute);
                  final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute);

                  // Check overlap inside dialog
                  if (!widget.allowOverlap) {
                    final timeEntryRepo = context.read<TimeEntryRepository>();
                    final existingEntries = timeEntryRepo.getByDateRange(
                      DateTime(start.year, start.month, start.day),
                      DateTime(start.year, start.month, start.day).add(const Duration(days: 1)),
                    );
                    final hasOverlap = existingEntries.any((existing) {
                      if (existing.endTime == null) return false;
                      // Truncate to minute precision — timer-created entries may have seconds
                      final eStart = DateTime(existing.startTime.year, existing.startTime.month, existing.startTime.day, existing.startTime.hour, existing.startTime.minute);
                      final eEnd = DateTime(existing.endTime!.year, existing.endTime!.month, existing.endTime!.day, existing.endTime!.hour, existing.endTime!.minute);
                      return start.isBefore(eEnd) && end.isAfter(eStart);
                    });
                    if (hasOverlap) {
                      setState(() => _overlapError = tr('time_entries.overlap_error'));
                      return;
                    }
                  }

                  final entry = TimeEntryModel(
                    id: const Uuid().v4(),
                    projectId: _selectedProject!.id,
                    taskId: _selectedTask!.id,
                    startTime: start,
                    endTime: end,
                    durationSeconds: end.difference(start).inSeconds,
                    notes: _notesController.text,
                    createdAt: DateTime.now(),
                    isBillable: _isBillable,
                  );

                  widget.onSave(entry);
                  Navigator.pop(context);
                }
              : null,
          icon: const Icon(Icons.save),
          label: Text(tr('common.save')),
        ),
      ],
    );
  }

  bool _isValidTimeRange() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    return endMinutes > startMinutes;
  }

  Widget _buildDurationPreview(BuildContext context) {
    if (!_isValidTimeRange()) {
      return Text('${tr('time_tracking.duration')}: --', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red));
    }
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final durationSeconds = (endMinutes - startMinutes) * 60;
    return Text(
      '${tr('time_tracking.duration')}: ${TimeFormatter.formatDuration(durationSeconds, showSeconds: false)}',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

// ---- Edit Entry Dialog ----

class _EditEntryDialog extends StatefulWidget {
  final TimeEntryModel entry;
  final List<ProjectModel> projects;
  final bool allowOverlap;
  final Function(TimeEntryModel entry) onSave;

  const _EditEntryDialog({required this.entry, required this.projects, required this.allowOverlap, required this.onSave});

  @override
  State<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<_EditEntryDialog> {
  ProjectModel? _selectedProject;
  TaskModel? _selectedTask;
  List<TaskModel> _tasks = [];
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late TextEditingController _notesController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late bool _isBillable;
  String? _overlapError;

  String _formatTimeOfDay(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay? _parseTime(String text) {
    final parts = text.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(widget.entry.startTime.year, widget.entry.startTime.month, widget.entry.startTime.day);
    _startTime = TimeOfDay.fromDateTime(widget.entry.startTime);
    _endTime = widget.entry.endTime != null
        ? TimeOfDay.fromDateTime(widget.entry.endTime!)
        : TimeOfDay.fromDateTime(widget.entry.startTime.add(Duration(seconds: widget.entry.durationSeconds)));
    _notesController = TextEditingController(text: widget.entry.notes);
    _startTimeController = TextEditingController(text: _formatTimeOfDay(_startTime));
    _endTimeController = TextEditingController(text: _formatTimeOfDay(_endTime));
    _isBillable = widget.entry.isBillable;

    _initProjectAndTask();
  }

  void _initProjectAndTask() {
    final projectRepo = context.read<ProjectRepository>();
    final taskRepo = context.read<TaskRepository>();

    final project = projectRepo.getById(widget.entry.projectId);
    if (project != null) {
      _selectedProject = project;
      _tasks = taskRepo.getByProject(project.id);
      final task = taskRepo.getById(widget.entry.taskId);
      if (task != null && _tasks.any((t) => t.id == task.id)) {
        _selectedTask = task;
      }
    }
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
  void dispose() {
    _notesController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('time_entries.edit_entry')),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project
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
                if (project != null) _loadTasks(project.id);
              },
            ),
            const SizedBox(height: 12),

            // Task
            DropdownButtonFormField<TaskModel>(
              decoration: InputDecoration(labelText: tr('time_tracking.select_task'), prefixIcon: const Icon(Icons.task_outlined)),
              isExpanded: true,
              initialValue: _selectedTask,
              items: _tasks.map((task) => DropdownMenuItem(value: task, child: Text(task.name))).toList(),
              onChanged: (task) => setState(() => _selectedTask = task),
            ),
            const SizedBox(height: 16),

            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(tr('time_entries.date')),
              subtitle: Text(DateFormat('EEEE, d MMMM yyyy', context.locale.languageCode).format(_selectedDate)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
            ),
            const SizedBox(height: 8),

            // Time inputs (manual text + picker icon)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startTimeController,
                    decoration: InputDecoration(
                      labelText: tr('time_entries.start'),
                      hintText: 'HH:mm',
                      prefixIcon: const Icon(Icons.play_arrow),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.access_time),
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: _startTime);
                          if (picked != null) {
                            setState(() {
                              _startTime = picked;
                              _startTimeController.text = _formatTimeOfDay(picked);
                              _overlapError = null;
                            });
                          }
                        },
                      ),
                    ),
                    onChanged: (text) {
                      final parsed = _parseTime(text);
                      if (parsed != null) {
                        setState(() {
                          _startTime = parsed;
                          _overlapError = null;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _endTimeController,
                    decoration: InputDecoration(
                      labelText: tr('time_entries.end'),
                      hintText: 'HH:mm',
                      prefixIcon: const Icon(Icons.stop),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.access_time),
                        onPressed: () async {
                          final picked = await showTimePicker(context: context, initialTime: _endTime);
                          if (picked != null) {
                            setState(() {
                              _endTime = picked;
                              _endTimeController.text = _formatTimeOfDay(picked);
                              _overlapError = null;
                            });
                          }
                        },
                      ),
                    ),
                    onChanged: (text) {
                      final parsed = _parseTime(text);
                      if (parsed != null) {
                        setState(() {
                          _endTime = parsed;
                          _overlapError = null;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Duration preview
            _buildDurationPreview(context),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: tr('time_tracking.notes'), prefixIcon: const Icon(Icons.notes)),
              maxLines: 2,
            ),
            const SizedBox(height: 8),

            // Billable toggle
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(tr('projects.billable')), value: _isBillable, onChanged: (v) => setState(() => _isBillable = v)),

            // Overlap error
            if (_overlapError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_overlapError!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
        FilledButton.icon(
          onPressed: _selectedProject != null && _selectedTask != null && _isValidTimeRange()
              ? () {
                  final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime.hour, _startTime.minute);
                  final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime.hour, _endTime.minute);

                  // Check overlap inside dialog
                  if (!widget.allowOverlap) {
                    final timeEntryRepo = context.read<TimeEntryRepository>();
                    final existingEntries = timeEntryRepo.getByDateRange(
                      DateTime(start.year, start.month, start.day),
                      DateTime(start.year, start.month, start.day).add(const Duration(days: 1)),
                    );
                    final hasOverlap = existingEntries.any((existing) {
                      if (existing.id == widget.entry.id) return false;
                      if (existing.endTime == null) return false;
                      // Truncate to minute precision — timer-created entries may have seconds
                      final eStart = DateTime(existing.startTime.year, existing.startTime.month, existing.startTime.day, existing.startTime.hour, existing.startTime.minute);
                      final eEnd = DateTime(existing.endTime!.year, existing.endTime!.month, existing.endTime!.day, existing.endTime!.hour, existing.endTime!.minute);
                      return start.isBefore(eEnd) && end.isAfter(eStart);
                    });
                    if (hasOverlap) {
                      setState(() => _overlapError = tr('time_entries.overlap_error'));
                      return;
                    }
                  }

                  final updatedEntry = widget.entry.copyWith(
                    projectId: _selectedProject!.id,
                    taskId: _selectedTask!.id,
                    startTime: start,
                    endTime: end,
                    durationSeconds: end.difference(start).inSeconds,
                    notes: _notesController.text,
                    isBillable: _isBillable,
                  );

                  widget.onSave(updatedEntry);
                  Navigator.pop(context);
                }
              : null,
          icon: const Icon(Icons.save),
          label: Text(tr('common.save')),
        ),
      ],
    );
  }

  bool _isValidTimeRange() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    return endMinutes > startMinutes;
  }

  Widget _buildDurationPreview(BuildContext context) {
    if (!_isValidTimeRange()) {
      return Text('${tr('time_tracking.duration')}: --', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red));
    }
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final durationSeconds = (endMinutes - startMinutes) * 60;
    return Text(
      '${tr('time_tracking.duration')}: ${TimeFormatter.formatDuration(durationSeconds, showSeconds: false)}',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
