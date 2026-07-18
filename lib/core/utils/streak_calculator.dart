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
  /// Returns 0 if there are no completions or if the most recent completion
  /// was more than 1 day ago (streak is broken).
  static int currentStreak(List<DateTime> completionDates) {
    if (completionDates.isEmpty) return 0;

    final sorted = _sortedUniqueDays(completionDates);
    final today = DateTime.now().startOfDay;
    final yesterday = today.subtract(const Duration(days: 1));

    // Streak is alive if the last completion was today or yesterday.
    if (!sorted.last.isSameDay(today) && !sorted.last.isSameDay(yesterday)) {
      return 0;
    }

    int streak = 1;
    for (int i = sorted.length - 1; i > 0; i--) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Calculates the longest streak ever recorded.
  static int longestStreak(List<DateTime> completionDates) {
    if (completionDates.isEmpty) return 0;

    final sorted = _sortedUniqueDays(completionDates);
    int longest = 1;
    int current = 1;

    for (int i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
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
