class TimeFormatter {
  TimeFormatter._();

  /// Format duration in seconds to HH:MM:SS
  static String formatDuration(int totalSeconds, {bool showSeconds = true}) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (showSeconds) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }

  /// Format duration in seconds to decimal hours (e.g. 1.5h)
  static String formatDecimalHours(int totalSeconds) {
    final hours = totalSeconds / 3600;
    return '${hours.toStringAsFixed(2)}h';
  }

  /// Format duration in seconds to human readable (e.g. "2h 30m")
  static String formatHumanReadable(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else if (minutes > 0) {
      return '${minutes}m';
    }
    return '0m';
  }

  /// Round duration in seconds to nearest interval
  static int roundToMinutes(int totalSeconds, int roundToMinutes) {
    if (roundToMinutes <= 0) return totalSeconds;
    final roundToSeconds = roundToMinutes * 60;
    return ((totalSeconds + roundToSeconds ~/ 2) ~/ roundToSeconds) * roundToSeconds;
  }

  /// Calculate revenue from duration and hourly rate
  static double calculateRevenue(int totalSeconds, double hourlyRate) {
    return (totalSeconds / 3600) * hourlyRate;
  }

  /// Format currency amount
  static String formatCurrency(double amount, String currency) {
    return '${amount.toStringAsFixed(2)} $currency';
  }
}
