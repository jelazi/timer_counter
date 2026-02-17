import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/time_formatter.dart';
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

  @override
  void initState() {
    super.initState();
    context.read<StatisticsBloc>().add(ChangeStatisticsRange(_selectedRange));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StatisticsBloc, StatisticsState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, state),
                const SizedBox(height: 24),
                if (state is StatisticsLoaded) ...[
                  _buildSummaryCards(context, state),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, StatisticsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(tr('statistics.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'today', label: Text(tr('time_tracking.today'))),
                    ButtonSegment(value: 'week', label: Text(tr('time_tracking.this_week'))),
                    ButtonSegment(value: 'month', label: Text(tr('time_tracking.this_month'))),
                    ButtonSegment(value: 'year', label: Text(tr('statistics.this_year'))),
                  ],
                  selected: _selectedRange != 'custom' ? {_selectedRange} : {},
                  emptySelectionAllowed: true,
                  onSelectionChanged: (selected) {
                    if (selected.isNotEmpty) {
                      setState(() => _selectedRange = selected.first);
                      context.read<StatisticsBloc>().add(ChangeStatisticsRange(selected.first));
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _showCustomRangePicker(context),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.date_range, size: 18), const SizedBox(width: 4), Text(tr('statistics.custom_range'))]),
                ),
              ],
            ),
          ],
        ),
        if (state is StatisticsLoaded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${DateFormat('d.M.yyyy', context.locale.languageCode).format(state.startDate)} — ${DateFormat('d.M.yyyy', context.locale.languageCode).format(state.endDate)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ),
          ),
      ],
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
                            value: selectedYear,
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
                            value: selectedMonth,
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
                      value: selectedYear,
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
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: tr('statistics.worked_hours'),
            value: TimeFormatter.formatHumanReadable(state.totalSeconds),
            icon: Icons.access_time,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(title: tr('statistics.billable_hours'), value: TimeFormatter.formatHumanReadable(state.billableSeconds), icon: Icons.attach_money, color: Colors.green),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(title: tr('statistics.total_revenue'), value: '${state.totalRevenue.toStringAsFixed(0)} CZK', icon: Icons.monetization_on, color: Colors.orange),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: tr('statistics.average_daily'),
            value: TimeFormatter.formatHumanReadable(state.averageDailySeconds.round()),
            icon: Icons.trending_up,
            color: Colors.purple,
          ),
        ),
      ],
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
      bars = List.generate(24, (i) => _ChartBar(label: '${i.toString().padLeft(2, '0')}', hours: hourlySeconds[i] / 3600));
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
    final chartMaxY = maxY > 0 ? maxY * 1.2 : 1.0;

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
            Expanded(
              child: ListView.builder(
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
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
