import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/time_formatter.dart';
import '../../data/repositories/monthly_hours_target_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../blocs/statistics/statistics_bloc.dart';
import '../blocs/statistics/statistics_event.dart';
import '../blocs/statistics/statistics_state.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedRange = 'week';
  int _periodOffset = 0; // 0 = current period, -1 = previous, etc.

  @override
  void initState() {
    super.initState();
    _dispatchRange();
  }

  void _dispatchRange() {
    final dates = _getDateRange(_selectedRange, _periodOffset);
    context.read<StatisticsBloc>().add(LoadStatistics(startDate: dates.$1, endDate: dates.$2, range: _selectedRange));
  }

  /// Calculate start/end date for a given range and offset
  (DateTime, DateTime) _getDateRange(String range, int offset) {
    final now = DateTime.now();
    switch (range) {
      case 'today':
        final day = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
        return (day, day.add(const Duration(days: 1)));
      case 'week':
        final currentWeekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        final weekStart = currentWeekStart.add(Duration(days: offset * 7));
        return (weekStart, weekStart.add(const Duration(days: 7)));
      case 'month':
        final targetMonth = DateTime(now.year, now.month + offset, 1);
        final endOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0, 23, 59, 59);
        return (targetMonth, endOfMonth);
      case 'year':
        final targetYear = DateTime(now.year + offset, 1, 1);
        final endOfYear = DateTime(targetYear.year, 12, 31, 23, 59, 59);
        return (targetYear, endOfYear);
      default:
        return (DateTime(now.year, now.month, now.day), DateTime(now.year, now.month, now.day + 1));
    }
  }

  /// Format date range label based on selected range
  String _formatRangeLabel(String range, int offset, String locale) {
    final dates = _getDateRange(range, offset);
    final start = dates.$1;
    final end = dates.$2;
    switch (range) {
      case 'today':
        return DateFormat('EEEE, d. MMMM yyyy', locale).format(start);
      case 'week':
        final weekEnd = end.subtract(const Duration(days: 1));
        return '${DateFormat('d.M.', locale).format(start)} — ${DateFormat('d.M.yyyy', locale).format(weekEnd)}';
      case 'month':
        return DateFormat('MMMM yyyy', locale).format(start);
      case 'year':
        return '${start.year}';
      default:
        return '${DateFormat('d.M.yyyy', locale).format(start)} — ${DateFormat('d.M.yyyy', locale).format(end)}';
    }
  }

  /// Get label for the "back to current period" button based on selected range
  String _getCurrentPeriodLabel() {
    switch (_selectedRange) {
      case 'today':
        return tr('time_tracking.today');
      case 'week':
        return tr('time_tracking.this_week');
      case 'month':
        return tr('time_tracking.this_month');
      case 'year':
        return tr('statistics.this_year');
      default:
        return tr('time_tracking.today');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StatisticsBloc, StatisticsState>(
      builder: (context, state) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: isMobile ? _buildMobileStatistics(context, state, isMobile) : _buildDesktopStatistics(context, state, isMobile),
          ),
        );
      },
    );
  }

  Widget _buildDesktopStatistics(BuildContext context, StatisticsState state, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, state),
        const SizedBox(height: 8),
        _buildProjectFilter(context, state),
        const SizedBox(height: 24),
        if (state is StatisticsLoaded) ...[
          _buildSummaryCards(context, state),
          if (_selectedRange == 'month') ...[const SizedBox(height: 12), _buildMonthlyTargetsProgress(context, state)],
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildDailyChart(context, state)),
                const SizedBox(width: 16),
                Expanded(child: _buildProjectDistribution(context, state)),
              ],
            ),
          ),
        ] else if (state is StatisticsLoading) ...[
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ] else ...[
          Expanded(child: Center(child: Text(tr('statistics.no_data')))),
        ],
      ],
    );
  }

  Widget _buildMobileStatistics(BuildContext context, StatisticsState state, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, state),
        const SizedBox(height: 8),
        _buildProjectFilter(context, state),
        const SizedBox(height: 16),
        if (state is StatisticsLoaded) ...[
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(context, state),
                  if (_selectedRange == 'month') ...[const SizedBox(height: 12), _buildMonthlyTargetsProgress(context, state)],
                  const SizedBox(height: 16),
                  SizedBox(height: 300, child: _buildDailyChart(context, state)),
                  const SizedBox(height: 16),
                  SizedBox(height: 350, child: _buildProjectDistribution(context, state)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ] else if (state is StatisticsLoading) ...[
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ] else ...[
          Expanded(child: Center(child: Text(tr('statistics.no_data')))),
        ],
      ],
    );
  }

  Widget _buildHeader(BuildContext context, StatisticsState state) {
    final locale = context.locale.languageCode;

    final titleWidget = Text(tr('statistics.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold));
    final segmentedButton = SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'today', label: Text(tr('statistics.select_day'))),
        ButtonSegment(value: 'week', label: Text(tr('statistics.select_week'))),
        ButtonSegment(value: 'month', label: Text(tr('statistics.select_month'))),
        ButtonSegment(value: 'year', label: Text(tr('statistics.select_year'))),
      ],
      selected: _selectedRange != 'custom' ? {_selectedRange} : {},
      emptySelectionAllowed: true,
      onSelectionChanged: (selected) {
        if (selected.isNotEmpty) {
          setState(() {
            _selectedRange = selected.first;
            _periodOffset = 0;
          });
          _dispatchRange();
        }
      },
    );
    final customRangeButton = FilledButton.tonal(
      onPressed: () => _showCustomRangePicker(context),
      child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.date_range, size: 18), const SizedBox(width: 4), Text(tr('statistics.custom_range'))]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget,
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: segmentedButton),
                  const SizedBox(height: 8),
                  customRangeButton,
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                titleWidget,
                Row(mainAxisSize: MainAxisSize.min, children: [segmentedButton, const SizedBox(width: 8), customRangeButton]),
              ],
            );
          },
        ),
        if (_selectedRange != 'custom')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() => _periodOffset--);
                    _dispatchRange();
                  },
                  tooltip: tr('pdf_reports.previous_month'),
                ),
                const SizedBox(width: 8),
                Text(_formatRangeLabel(_selectedRange, _periodOffset, locale), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() => _periodOffset++);
                    _dispatchRange();
                  },
                  tooltip: tr('pdf_reports.next_month'),
                ),
                if (_periodOffset != 0) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      setState(() => _periodOffset = 0);
                      _dispatchRange();
                    },
                    icon: const Icon(Icons.today, size: 18),
                    label: Text(_getCurrentPeriodLabel()),
                  ),
                ],
              ],
            ),
          ),
        if (_selectedRange == 'custom' && state is StatisticsLoaded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${DateFormat('d.M.yyyy', locale).format(state.startDate)} — ${DateFormat('d.M.yyyy', locale).format(state.endDate)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProjectFilter(BuildContext context, StatisticsState state) {
    final projects = context.read<ProjectRepository>().getAll().where((p) => !p.isArchived).toList();
    final filteredIds = state is StatisticsLoaded ? state.filteredProjectIds : <String>[];
    final allSelected = filteredIds.isEmpty;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          if (!allSelected)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ActionChip(
                label: Text(tr('common.clear')),
                onPressed: () => context.read<StatisticsBloc>().add(const FilterStatisticsProjects([])),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ...projects.map((project) {
            final isSelected = allSelected || filteredIds.contains(project.id);
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilterChip(
                label: Text(project.name),
                selected: isSelected,
                selectedColor: Color(project.colorValue).withValues(alpha: 0.3),
                avatar: CircleAvatar(backgroundColor: Color(project.colorValue), radius: 6),
                visualDensity: VisualDensity.compact,
                onSelected: (selected) {
                  if (allSelected) {
                    // Switching from "all" to explicit: select all except the one being toggled off
                    final allIds = projects.map((p) => p.id).toList();
                    if (!selected) {
                      allIds.remove(project.id);
                    }
                    context.read<StatisticsBloc>().add(FilterStatisticsProjects(allIds));
                  } else {
                    final newIds = List<String>.from(filteredIds);
                    if (selected) {
                      newIds.add(project.id);
                    } else {
                      newIds.remove(project.id);
                    }
                    // If all are selected again, switch back to empty (= all)
                    if (newIds.length == projects.length) {
                      context.read<StatisticsBloc>().add(const FilterStatisticsProjects([]));
                    } else {
                      context.read<StatisticsBloc>().add(FilterStatisticsProjects(newIds));
                    }
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showCustomRangePicker(BuildContext parentContext) {
    final statisticsBloc = parentContext.read<StatisticsBloc>();
    final locale = parentContext.locale.languageCode;
    final now = DateTime.now();

    showDialog(
      context: parentContext,
      builder: (_) {
        String mode = 'month';
        DateTime selectedDate = now;
        int selectedYear = now.year;
        int selectedMonth = now.month;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Widget buildModeControls() {
              switch (mode) {
                case 'day':
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(DateFormat('d MMMM yyyy', locale).format(selectedDate)),
                    subtitle: Text(tr('statistics.select_day')),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                  );
                case 'week':
                  final weekStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day - (selectedDate.weekday - 1));
                  final weekEnd = weekStart.add(const Duration(days: 6));
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.view_week),
                    title: Text('${DateFormat('d.M.', locale).format(weekStart)} — ${DateFormat('d.M.yyyy', locale).format(weekEnd)}'),
                    subtitle: Text(tr('statistics.select_week')),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 7)),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                  );
                case 'month':
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            decoration: InputDecoration(labelText: tr('statistics.select_year')),
                            initialValue: selectedYear,
                            items: List.generate(now.year - 2019, (i) => 2020 + i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => selectedYear = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            decoration: InputDecoration(labelText: tr('statistics.select_month')),
                            initialValue: selectedMonth,
                            items: List.generate(
                              12,
                              (i) => i + 1,
                            ).map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MMMM', locale).format(DateTime(2024, m))))).toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => selectedMonth = v);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                case 'year':
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: DropdownButtonFormField<int>(
                      decoration: InputDecoration(labelText: tr('statistics.select_year')),
                      initialValue: selectedYear,
                      isExpanded: true,
                      items: List.generate(now.year - 2019, (i) => 2020 + i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedYear = v);
                      },
                    ),
                  );
                default:
                  return const SizedBox();
              }
            }

            return AlertDialog(
              title: Text(tr('statistics.select_period')),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'day', label: Text(tr('statistics.select_day'))),
                        ButtonSegment(value: 'week', label: Text(tr('statistics.select_week'))),
                        ButtonSegment(value: 'month', label: Text(tr('statistics.select_month'))),
                        ButtonSegment(value: 'year', label: Text(tr('statistics.select_year'))),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) => setDialogState(() => mode = s.first),
                    ),
                    const SizedBox(height: 16),
                    buildModeControls(),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('common.cancel'))),
                FilledButton(
                  onPressed: () {
                    DateTime startDate, endDate;
                    switch (mode) {
                      case 'day':
                        startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                        endDate = startDate.add(const Duration(days: 1));
                        break;
                      case 'week':
                        startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day - (selectedDate.weekday - 1));
                        endDate = startDate.add(const Duration(days: 7));
                        break;
                      case 'month':
                        startDate = DateTime(selectedYear, selectedMonth, 1);
                        endDate = DateTime(selectedYear, selectedMonth + 1, 0, 23, 59, 59);
                        break;
                      case 'year':
                        startDate = DateTime(selectedYear, 1, 1);
                        endDate = DateTime(selectedYear, 12, 31, 23, 59, 59);
                        break;
                      default:
                        return;
                    }
                    Navigator.pop(dialogContext);
                    setState(() => _selectedRange = 'custom');
                    statisticsBloc.add(LoadStatistics(startDate: startDate, endDate: endDate));
                  },
                  child: Text(tr('statistics.apply')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCards(BuildContext context, StatisticsLoaded state) {
    final cards = [
      _StatCard(
        title: tr('statistics.worked_hours'),
        value: TimeFormatter.formatHumanReadable(state.totalSeconds),
        icon: Icons.access_time,
        color: Theme.of(context).colorScheme.primary,
      ),
      _StatCard(title: tr('statistics.billable_hours'), value: TimeFormatter.formatHumanReadable(state.billableSeconds), icon: Icons.attach_money, color: Colors.green),
      _StatCard(title: tr('statistics.total_revenue'), value: '${state.totalRevenue.toStringAsFixed(0)} CZK', icon: Icons.monetization_on, color: Colors.orange),
      _StatCard(title: tr('statistics.average_daily'), value: TimeFormatter.formatHumanReadable(state.averageDailySeconds.round()), icon: Icons.trending_up, color: Colors.purple),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
            const SizedBox(width: 16),
            Expanded(child: cards[2]),
            const SizedBox(width: 16),
            Expanded(child: cards[3]),
          ],
        );
      },
    );
  }

  Widget _buildMonthlyTargetsProgress(BuildContext context, StatisticsLoaded state) {
    final targetRepo = context.read<MonthlyHoursTargetRepository>();
    final settingsRepo = context.read<SettingsRepository>();
    final targets = targetRepo.getAll();
    if (targets.isEmpty) return const SizedBox.shrink();

    // Calculate hours per project from the statistics entries
    final timeEntryRepo = context.read<TimeEntryRepository>();
    final dates = _getDateRange(_selectedRange, _periodOffset);
    final entries = timeEntryRepo.getByDateRange(dates.$1, dates.$2);
    final hoursPerProject = <String, double>{};
    for (final entry in entries) {
      hoursPerProject.update(entry.projectId, (val) => val + entry.actualDurationSeconds / 3600.0, ifAbsent: () => entry.actualDurationSeconds / 3600.0);
    }

    // Calculate remaining working days in the viewed month
    final monthStart = dates.$1;
    final lastDayOfMonth = DateTime(monthStart.year, monthStart.month + 1, 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Start counting from today (or month start if viewing a future month)
    final countFrom = today.isAfter(monthStart) ? today : monthStart;
    int remainingWorkDays = 0;
    for (DateTime d = countFrom; !d.isAfter(lastDayOfMonth); d = d.add(const Duration(days: 1))) {
      if (settingsRepo.getExpectedHoursForDay(d.weekday) > 0) {
        remainingWorkDays++;
      }
    }

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: targets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final target = targets[index];
          final workedHours = target.projectIds.fold(0.0, (sum, pid) => sum + (hoursPerProject[pid] ?? 0));
          final progress = target.targetHours > 0 ? (workedHours / target.targetHours).clamp(0.0, 1.0) : 0.0;
          final isComplete = workedHours >= target.targetHours;
          final remainingHours = (target.targetHours - workedHours).clamp(0.0, double.infinity);
          final dailyNeeded = remainingWorkDays > 0 && !isComplete ? remainingHours / remainingWorkDays : 0.0;

          return Container(
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isComplete ? Colors.green.withValues(alpha: 0.5) : Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(isComplete ? Icons.check_circle : Icons.track_changes, size: 14, color: isComplete ? Colors.green : Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        target.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${workedHours.toStringAsFixed(1)}/${target.targetHours.toStringAsFixed(0)}h',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: isComplete ? Colors.green : null),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: isComplete ? Colors.green : Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (!isComplete && remainingWorkDays > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    tr('monthly_targets.daily_needed', namedArgs: {'hours': dailyNeeded.toStringAsFixed(1), 'days': '$remainingWorkDays'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9, color: Theme.of(context).colorScheme.tertiary),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyChart(BuildContext context, StatisticsLoaded state) {
    final locale = context.locale.languageCode;
    final range = state.range;

    // Build chart data based on range
    List<_ChartBar> bars;

    if (range == 'today') {
      // Show 24 hours
      final timeEntryRepo = context.read<TimeEntryRepository>();
      final entries = timeEntryRepo.getByDateRange(state.startDate, state.endDate);
      final hourlySeconds = List<int>.filled(24, 0);
      for (final entry in entries) {
        final hour = entry.startTime.hour;
        hourlySeconds[hour] += entry.actualDurationSeconds;
      }
      bars = List.generate(24, (i) => _ChartBar(label: i.toString().padLeft(2, '0'), hours: hourlySeconds[i] / 3600));
    } else if (range == 'week') {
      // Show all 7 days of the week (Mon-Sun)
      final weekStart = state.startDate;
      final dailyMap = <DateTime, double>{};
      for (final ds in state.dailyStatistics) {
        dailyMap[DateTime(ds.date.year, ds.date.month, ds.date.day)] = ds.totalSeconds / 3600;
      }
      bars = List.generate(7, (i) {
        final day = weekStart.add(Duration(days: i));
        final dayKey = DateTime(day.year, day.month, day.day);
        return _ChartBar(label: DateFormat('E', locale).format(day), hours: dailyMap[dayKey] ?? 0);
      });
    } else if (range == 'month') {
      // Show all days of the month
      final daysInMonth = DateTime(state.startDate.year, state.startDate.month + 1, 0).day;
      final dailyMap = <int, double>{};
      for (final ds in state.dailyStatistics) {
        dailyMap[ds.date.day] = ds.totalSeconds / 3600;
      }
      bars = List.generate(daysInMonth, (i) {
        final dayNum = i + 1;
        return _ChartBar(label: '$dayNum', hours: dailyMap[dayNum] ?? 0);
      });
    } else if (range == 'year') {
      // Show 12 months
      final monthlySeconds = List<int>.filled(12, 0);
      for (final ds in state.dailyStatistics) {
        monthlySeconds[ds.date.month - 1] += ds.totalSeconds;
      }
      bars = List.generate(12, (i) {
        final monthDate = DateTime(state.startDate.year, i + 1);
        return _ChartBar(label: DateFormat('MMM', locale).format(monthDate), hours: monthlySeconds[i] / 3600);
      });
    } else {
      // Custom range: show daily stats as-is
      if (state.dailyStatistics.isEmpty) {
        return Card(child: Center(child: Text(tr('statistics.no_data'))));
      }
      bars = state.dailyStatistics.map((ds) {
        return _ChartBar(label: DateFormat('d/M', locale).format(ds.date), hours: ds.totalSeconds / 3600);
      }).toList();
    }

    if (bars.isEmpty) {
      return Card(child: Center(child: Text(tr('statistics.no_data'))));
    }

    final maxY = bars.map((b) => b.hours).fold(0.0, (a, b) => a > b ? a : b);
    // Get expected daily hours from work schedule settings
    final settingsRepo = context.read<SettingsRepository>();
    double expectedDailyHours;
    if (range == 'today') {
      final dates = _getDateRange(range, _periodOffset);
      expectedDailyHours = settingsRepo.getExpectedHoursForDay(dates.$1.weekday);
    } else {
      // Average of enabled working days
      double totalHours = 0;
      int enabledDays = 0;
      for (int wd = 1; wd <= 7; wd++) {
        final h = settingsRepo.getExpectedHoursForDay(wd);
        if (h > 0) {
          totalHours += h;
          enabledDays++;
        }
      }
      expectedDailyHours = enabledDays > 0 ? totalHours / enabledDays : 0;
    }
    final chartMaxY = [maxY, expectedDailyHours].reduce((a, b) => a > b ? a : b) * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('statistics.daily_hours'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(enabled: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (expectedDailyHours > 0 && range != 'year' && range != 'today')
                        HorizontalLine(
                          y: expectedDailyHours,
                          color: Colors.red.withValues(alpha: 0.5),
                          strokeWidth: 2,
                          dashArray: [6, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: TextStyle(fontSize: 10, color: Colors.red.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                            labelResolver: (_) => '${expectedDailyHours.toStringAsFixed(1)}h',
                          ),
                        ),
                    ],
                  ),
                  alignment: BarChartAlignment.spaceAround,
                  maxY: chartMaxY,
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < bars.length) {
                            // For month with many days, skip some labels
                            if (bars.length > 15 && index % (bars.length > 20 ? 5 : 3) != 0) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(bars[index].label, style: const TextStyle(fontSize: 9)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toStringAsFixed(0)}h', style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY > 8 ? 4 : 2),
                  barGroups: bars.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.hours,
                          color: e.value.hours > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          width: bars.length > 20 ? 8 : (bars.length > 12 ? 14 : 20),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectDistribution(BuildContext context, StatisticsLoaded state) {
    if (state.projectStatistics.isEmpty) {
      return Card(child: Center(child: Text(tr('statistics.no_data'))));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('statistics.distribution'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: state.projectStatistics.map((ps) {
                    final percentage = state.totalSeconds > 0 ? (ps.totalSeconds / state.totalSeconds * 100) : 0.0;
                    return PieChartSectionData(
                      value: ps.totalSeconds.toDouble(),
                      title: '${percentage.toStringAsFixed(0)}%',
                      color: Color(ps.colorValue),
                      radius: 60,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.projectStatistics.length,
                itemBuilder: (context, index) {
                  final ps = state.projectStatistics[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: Color(ps.colorValue), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(ps.projectName, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                        ),
                        Text(TimeFormatter.formatHumanReadable(ps.totalSeconds), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ChartBar {
  final String label;
  final double hours;

  const _ChartBar({required this.label, required this.hours});
}
