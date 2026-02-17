import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/time_entry_repository.dart';
import 'statistics_event.dart';
import 'statistics_state.dart';

class StatisticsBloc extends Bloc<StatisticsEvent, StatisticsState> {
  final TimeEntryRepository _timeEntryRepository;
  final ProjectRepository _projectRepository;

  StatisticsBloc({required TimeEntryRepository timeEntryRepository, required ProjectRepository projectRepository})
    : _timeEntryRepository = timeEntryRepository,
      _projectRepository = projectRepository,
      super(const StatisticsInitial()) {
    on<LoadStatistics>(_onLoadStatistics);
    on<ChangeStatisticsRange>(_onChangeRange);
  }

  void _onLoadStatistics(LoadStatistics event, Emitter<StatisticsState> emit) {
    try {
      emit(const StatisticsLoading());
      _loadStats(event.startDate, event.endDate, 'custom', emit);
    } catch (e) {
      emit(StatisticsError(e.toString()));
    }
  }

  void _onChangeRange(ChangeStatisticsRange event, Emitter<StatisticsState> emit) {
    try {
      emit(const StatisticsLoading());
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      switch (event.range) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          endDate = startDate.add(const Duration(days: 1));
          break;
        case 'week':
          startDate = DateTime(now.year, now.month, now.day - (now.weekday - 1));
          endDate = startDate.add(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        default:
          startDate = DateTime(now.year, now.month, now.day);
          endDate = startDate.add(const Duration(days: 1));
      }

      _loadStats(startDate, endDate, event.range, emit);
    } catch (e) {
      emit(StatisticsError(e.toString()));
    }
  }

  void _loadStats(DateTime startDate, DateTime endDate, String range, Emitter<StatisticsState> emit) {
    final entries = _timeEntryRepository.getByDateRange(startDate, endDate);
    final projects = _projectRepository.getAll();

    int totalSeconds = 0;
    int billableSeconds = 0;
    int nonBillableSeconds = 0;
    double totalRevenue = 0;

    // Project statistics
    final Map<String, int> projectSeconds = {};
    final Map<String, double> projectRevenue = {};

    for (final entry in entries) {
      final seconds = entry.actualDurationSeconds;
      totalSeconds += seconds;

      if (entry.isBillable) {
        billableSeconds += seconds;
      } else {
        nonBillableSeconds += seconds;
      }

      projectSeconds[entry.projectId] = (projectSeconds[entry.projectId] ?? 0) + seconds;

      // Find project hourly rate
      final project = projects.where((p) => p.id == entry.projectId).toList();
      if (project.isNotEmpty && entry.isBillable) {
        final revenue = (seconds / 3600) * project.first.hourlyRate;
        totalRevenue += revenue;
        projectRevenue[entry.projectId] = (projectRevenue[entry.projectId] ?? 0) + revenue;
      }
    }

    final projectStatistics = projectSeconds.entries.map((e) {
      final project = projects.where((p) => p.id == e.key).toList();
      return ProjectStatistic(
        projectId: e.key,
        projectName: project.isNotEmpty ? project.first.name : 'Unknown',
        colorValue: project.isNotEmpty ? project.first.colorValue : 0xFF6366F1,
        totalSeconds: e.value,
        revenue: projectRevenue[e.key] ?? 0,
        isBillable: project.isNotEmpty ? project.first.isBillable : true,
      );
    }).toList()..sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));

    // Daily statistics
    final Map<DateTime, int> dailySeconds = {};
    final Map<DateTime, double> dailyRevenue = {};

    for (final entry in entries) {
      final day = DateTime(entry.startTime.year, entry.startTime.month, entry.startTime.day);
      dailySeconds[day] = (dailySeconds[day] ?? 0) + entry.actualDurationSeconds;

      final project = projects.where((p) => p.id == entry.projectId).toList();
      if (project.isNotEmpty && entry.isBillable) {
        final revenue = (entry.actualDurationSeconds / 3600) * project.first.hourlyRate;
        dailyRevenue[day] = (dailyRevenue[day] ?? 0) + revenue;
      }
    }

    final dailyStatistics = dailySeconds.entries.map((e) {
      return DailyStatistic(date: e.key, totalSeconds: e.value, revenue: dailyRevenue[e.key] ?? 0);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    final daysInRange = endDate.difference(startDate).inDays;
    final averageDailySeconds = daysInRange > 0 ? totalSeconds / daysInRange : totalSeconds.toDouble();

    emit(
      StatisticsLoaded(
        startDate: startDate,
        endDate: endDate,
        range: range,
        totalSeconds: totalSeconds,
        billableSeconds: billableSeconds,
        nonBillableSeconds: nonBillableSeconds,
        totalRevenue: totalRevenue,
        averageDailySeconds: averageDailySeconds,
        projectStatistics: projectStatistics,
        dailyStatistics: dailyStatistics,
      ),
    );
  }
}
