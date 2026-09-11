import 'package:equatable/equatable.dart';

/// Working hours of a single weekday, as `HH:mm` strings.
///
/// Plain value type on purpose — it is persisted as individual Hive settings
/// keys and as JSON in PocketBase, never as a Hive object, so an older app
/// version reading the same box never meets an unknown adapter.
class WorkDaySchedule extends Equatable {
  final String start;
  final String end;
  final bool enabled;

  const WorkDaySchedule({required this.start, required this.end, required this.enabled});

  double get hours {
    final startMinutes = _minutesOf(start);
    final endMinutes = _minutesOf(end);
    final diff = endMinutes - startMinutes;
    return diff <= 0 ? 0 : diff / 60.0;
  }

  WorkDaySchedule copyWith({String? start, String? end, bool? enabled}) {
    return WorkDaySchedule(start: start ?? this.start, end: end ?? this.end, enabled: enabled ?? this.enabled);
  }

  Map<String, dynamic> toJson() => {'start': start, 'end': end, 'enabled': enabled};

  factory WorkDaySchedule.fromJson(Map<dynamic, dynamic> json) => WorkDaySchedule(
    start: json['start'] as String? ?? '08:00',
    end: json['end'] as String? ?? '16:30',
    enabled: json['enabled'] as bool? ?? false,
  );

  static int _minutesOf(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return hours * 60 + minutes;
  }

  @override
  List<Object?> get props => [start, end, enabled];
}
