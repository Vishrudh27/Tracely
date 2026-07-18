/// Extension methods on [DateTime] for common Tracely operations.
///
/// Centralizes all date manipulation logic so it's testable and consistent.
extension DateExtensions on DateTime {
  // ---------------------------------------------------------------------------
  // Day comparison
  // ---------------------------------------------------------------------------

  /// Returns true if this DateTime represents the same calendar day as [other].
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Returns true if this DateTime is today.
  bool get isToday => isSameDay(DateTime.now());

  /// Returns true if this DateTime was yesterday.
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(yesterday);
  }

  // ---------------------------------------------------------------------------
  // Normalization
  // ---------------------------------------------------------------------------

  /// Returns this date normalized to midnight (00:00:00) in local time.
  /// Used when storing completion dates — we only care about the day, not time.
  DateTime get startOfDay => DateTime(year, month, day);

  /// Returns the first day (Monday) of the ISO week containing this date.
  DateTime get startOfWeek {
    final daysFromMonday = weekday - 1; // weekday: Mon=1, Sun=7
    return DateTime(year, month, day - daysFromMonday);
  }

  /// Returns the last day (Sunday) of the ISO week containing this date.
  DateTime get endOfWeek => startOfWeek.add(const Duration(days: 6));

  /// Returns the first day of this month.
  DateTime get startOfMonth => DateTime(year, month, 1);

  /// Returns the last day of this month.
  DateTime get endOfMonth => DateTime(year, month + 1, 0);

  // ---------------------------------------------------------------------------
  // Display helpers
  // ---------------------------------------------------------------------------

  /// Returns a relative label: "Today", "Yesterday", or "N days ago".
  String get relativeLabel {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    final diff = DateTime.now().startOfDay.difference(startOfDay).inDays;
    return '$diff days ago';
  }

  /// Returns the ISO week number (1–53) for this date.
  int get weekNumber {
    final startOfYear = DateTime(year, 1, 1);
    final firstMonday = startOfYear.weekday <= 4
        ? startOfYear.subtract(Duration(days: startOfYear.weekday - 1))
        : startOfYear.add(Duration(days: 8 - startOfYear.weekday));
    if (isBefore(firstMonday)) {
      return DateTime(year - 1, 12, 31).weekNumber;
    }
    return ((difference(firstMonday).inDays) / 7).floor() + 1;
  }
}

/// Extension on [DateTime?] for nullable safety.
extension NullableDateExtensions on DateTime? {
  bool get isToday => this?.isToday ?? false;
}
