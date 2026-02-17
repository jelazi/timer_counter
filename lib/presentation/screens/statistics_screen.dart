import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/time_formatter.dart';
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
                _buildHeader(context),
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(tr('statistics.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'today', label: Text(tr('time_tracking.today'))),
            ButtonSegment(value: 'week', label: Text(tr('time_tracking.this_week'))),
            ButtonSegment(value: 'month', label: Text(tr('time_tracking.this_month'))),
          ],
          selected: {_selectedRange},
          onSelectionChanged: (selected) {
            setState(() => _selectedRange = selected.first);
            context.read<StatisticsBloc>().add(ChangeStatisticsRange(_selectedRange));
          },
        ),
      ],
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
    if (state.dailyStatistics.isEmpty) {
      return Card(child: Center(child: Text(tr('statistics.no_data'))));
    }

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
                  maxY: state.dailyStatistics.map((e) => e.totalSeconds / 3600).fold(0.0, (a, b) => a > b ? a : b) * 1.2,
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < state.dailyStatistics.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(DateFormat('E').format(state.dailyStatistics[index].date), style: const TextStyle(fontSize: 10)),
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
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 2),
                  barGroups: state.dailyStatistics.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.totalSeconds / 3600,
                          color: Theme.of(context).colorScheme.primary,
                          width: 20,
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
