import 'package:equatable/equatable.dart';

class ProjectStatistic extends Equatable {
  final String projectId;
  final String projectName;
  final int colorValue;
  final int totalSeconds;
  final double revenue;
  final bool isBillable;

  const ProjectStatistic({
    required this.projectId,
    required this.projectName,
    required this.colorValue,
    required this.totalSeconds,
    required this.revenue,
    required this.isBillable,
  });

  @override
  List<Object?> get props =>
      [projectId, projectName, colorValue, totalSeconds, revenue, isBillable];
}

class DailyStatistic extends Equatable {
  final DateTime date;
  final int totalSeconds;
  final double revenue;

  const DailyStatistic({
    required this.date,
    required this.totalSeconds,
    required this.revenue,
  });

  @override
  List<Object?> get props => [date, totalSeconds, revenue];
}

abstract class StatisticsState extends Equatable {
  const StatisticsState();

  @override
  List<Object?> get props => [];
}

class StatisticsInitial extends StatisticsState {
  const StatisticsInitial();
}

class StatisticsLoading extends StatisticsState {
  const StatisticsLoading();
}

class StatisticsLoaded extends StatisticsState {
  final DateTime startDate;
  final DateTime endDate;
  final String range;
  final int totalSeconds;
  final int billableSeconds;
  final int nonBillableSeconds;
  final double totalRevenue;
  final double averageDailySeconds;
  final List<ProjectStatistic> projectStatistics;
  final List<DailyStatistic> dailyStatistics;

  const StatisticsLoaded({
    required this.startDate,
    required this.endDate,
    required this.range,
    required this.totalSeconds,
    required this.billableSeconds,
    required this.nonBillableSeconds,
    required this.totalRevenue,
    required this.averageDailySeconds,
    required this.projectStatistics,
    required this.dailyStatistics,
  });

  @override
  List<Object?> get props => [
        startDate,
        endDate,
        range,
        totalSeconds,
        billableSeconds,
        nonBillableSeconds,
        totalRevenue,
        averageDailySeconds,
        projectStatistics,
        dailyStatistics,
      ];
}

class StatisticsError extends StatisticsState {
  final String message;
  const StatisticsError(this.message);

  @override
  List<Object?> get props => [message];
}
