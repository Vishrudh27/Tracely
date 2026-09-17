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

  /// Whole calendar days from [other] up to this date.
  ///
  /// Compares via UTC so the result is a count of days on the calendar, not of
  /// elapsed hours. A plain `difference(...).inDays` truncates across a
  /// daylight-saving transition — a 23-hour local day reads as 0 days — which
  /// silently breaks streak counting in timezones that observe DST.
  int calendarDaysSince(DateTime other) {
    final self = DateTime.utc(year, month, day);
    final from = DateTime.utc(other.year, other.month, other.day);
    return self.difference(from).inDays;
  }

  /// Returns true if this DateTime is today.
  bool get isToday => isSameDay(DateTime.now());

  /// Returns true if this DateTime was yesterday.
  bool get isYesterday {
    final now = DateTime.now();
    return isSameDay(DateTime(now.year, now.month, now.day - 1));
  }

  // ---------------------------------------------------------------------------
  // Normalization
  // ---------------------------------------------------------------------------

  /// Returns this date normalized to midnight (00:00:00) in local time.
  /// Used when storing completion dates — we only care about the day, not time.
  DateTime get startOfDay => DateTime(year, month, day);

  /// This date shifted by [days] calendar days, still at local midnight.
  ///
  /// Prefer this over `add(Duration(days: n))`, which adds 24-hour blocks and
  /// therefore lands at 23:00 or 01:00 across a daylight-saving boundary —
  /// enough to miss a midnight-keyed lookup.
  DateTime addDays(int days) => DateTime(year, month, day + days);

  /// Returns the first day (Monday) of the ISO week containing this date.
  DateTime get startOfWeek {
    final daysFromMonday = weekday - 1; // weekday: Mon=1, Sun=7
    return DateTime(year, month, day - daysFromMonday);
  }

  /// Returns the last day (Sunday) of the ISO week containing this date.
  DateTime get endOfWeek => startOfWeek.addDays(6);

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
    final diff = DateTime.now().calendarDaysSince(this);
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
