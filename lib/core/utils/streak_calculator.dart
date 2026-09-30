import '../extensions/date_extensions.dart';

/// Pure Dart streak calculator.
///
/// All logic is stateless and testable — no Flutter dependencies.
/// Streak is defined as consecutive calendar days with at least one completion.
final class StreakCalculator {
  StreakCalculator._();

  /// Calculates the current streak from a sorted list of completion dates.
  ///
  /// [completionDates] must contain unique dates (one per calendar day),
  /// normalized to midnight. The list can be in any order.
  ///
  /// [isScheduled] marks which days the habit is meant to be done on. A day
  /// it returns false for is skipped — it neither counts toward the streak
  /// nor breaks it. Defaults to every day, the old all-days behavior; pass
  /// [isScheduledOn] (from `habit_schedule.dart`) for a habit with specific
  /// days, so a Mon–Fri habit's streak survives the weekend.
  ///
  /// Returns 0 if there are no completions, or if a scheduled day between
  /// the last completion and today was missed.
  static int currentStreak(
    List<DateTime> completionDates, {
    bool Function(DateTime day)? isScheduled,
  }) {
    if (completionDates.isEmpty) return 0;
    final scheduled = isScheduled ?? _alwaysScheduled;

    final sorted = _sortedUniqueDays(completionDates);
    final today = DateTime.now().startOfDay;

    // Broken if a scheduled day was missed between the last completion and
    // today. Today itself is excluded — it may just not be done yet.
    var cursor = sorted.last.addDays(1);
    while (cursor.isBefore(today)) {
      if (scheduled(cursor)) return 0;
      cursor = cursor.addDays(1);
    }

    int streak = 1;
    for (int i = sorted.length - 1; i > 0; i--) {
      if (_gapIsAllUnscheduled(sorted[i - 1], sorted[i], scheduled)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Calculates the longest streak ever recorded.
  ///
  /// See [currentStreak] for [isScheduled].
  static int longestStreak(
    List<DateTime> completionDates, {
    bool Function(DateTime day)? isScheduled,
  }) {
    if (completionDates.isEmpty) return 0;
    final scheduled = isScheduled ?? _alwaysScheduled;

    final sorted = _sortedUniqueDays(completionDates);
    int longest = 1;
    int current = 1;

    for (int i = 1; i < sorted.length; i++) {
      if (_gapIsAllUnscheduled(sorted[i - 1], sorted[i], scheduled)) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  static bool _alwaysScheduled(DateTime day) => true;

  /// True if every day strictly between [earlier] and [later] is a day the
  /// habit wasn't scheduled for — i.e. the gap is just rest days, not a
  /// missed one. Consecutive days (no days between) are always true, which
  /// is what makes a plain daily-habit gap of 1 still count as continuing.
  static bool _gapIsAllUnscheduled(
    DateTime earlier,
    DateTime later,
    bool Function(DateTime day) scheduled,
  ) {
    var day = earlier.addDays(1);
    while (day.isBefore(later)) {
      if (scheduled(day)) return false;
      day = day.addDays(1);
    }
    return true;
  }

  /// Returns sorted unique calendar days from a list of completion timestamps.
  static List<DateTime> _sortedUniqueDays(List<DateTime> dates) {
    final uniqueDays = <String, DateTime>{};
    for (final date in dates) {
      final key = '${date.year}-${date.month}-${date.day}';
      uniqueDays[key] = date.startOfDay;
    }
    final result = uniqueDays.values.toList();
    result.sort((a, b) => a.compareTo(b));
    return result;
  }

  /// Checks if today's completion is needed to continue the streak.
  static bool needsCompletionToday(List<DateTime> completionDates) {
    if (completionDates.isEmpty) return true;
    final sorted = _sortedUniqueDays(completionDates);
    final today = DateTime.now().startOfDay;
    return !sorted.last.isSameDay(today);
  }

  /// Returns the completion rate as a value between 0.0 and 1.0.
  ///
  /// [completedDays] — number of days with at least one completion.
  /// [totalDays] — total days the habit has been active.
  static double completionRate(int completedDays, int totalDays) {
    if (totalDays == 0) return 0.0;
    return (completedDays / totalDays).clamp(0.0, 1.0);
  }
}
