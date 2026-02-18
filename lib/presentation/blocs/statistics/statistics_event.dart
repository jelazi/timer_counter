import 'package:equatable/equatable.dart';

abstract class StatisticsEvent extends Equatable {
  const StatisticsEvent();

  @override
  List<Object?> get props => [];
}

class LoadStatistics extends StatisticsEvent {
  final DateTime startDate;
  final DateTime endDate;
  final String range;

  const LoadStatistics({required this.startDate, required this.endDate, this.range = 'custom'});

  @override
  List<Object?> get props => [startDate, endDate, range];
}

class ChangeStatisticsRange extends StatisticsEvent {
  final String range; // 'today', 'week', 'month', 'custom'

  const ChangeStatisticsRange(this.range);

  @override
  List<Object?> get props => [range];
}

class FilterStatisticsProjects extends StatisticsEvent {
  final List<String> projectIds;

  const FilterStatisticsProjects(this.projectIds);

  @override
  List<Object?> get props => [projectIds];
}
