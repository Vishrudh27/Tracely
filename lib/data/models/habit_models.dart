/// Pure Dart data classes used as return types from repositories.
///
/// These decouple the presentation layer from Drift-generated types.
/// Repositories map Drift rows → these classes before returning to the UI.
library;

// ---------------------------------------------------------------------------
// Habit + Category combined
// ---------------------------------------------------------------------------

/// A habit bundled with its category and today's completion status.
class HabitWithCompletion {
  const HabitWithCompletion({
    required this.habitId,
    required this.name,
    required this.emoji,
    required this.categoryName,
    required this.categoryEmoji,
    required this.categoryColorValue,
    required this.frequencyType,
    required this.frequencyConfig,
    required this.isCompletedToday,
    required this.sortOrder,
  });

  final int habitId;
  final String name;
  final String emoji; // habit emoji or falls back to category emoji
  final String categoryName;
  final String categoryEmoji;
  final int categoryColorValue;
  final String frequencyType;
  final String? frequencyConfig;
  final bool isCompletedToday;
  final int sortOrder;
}

// ---------------------------------------------------------------------------
// Daily progress
// ---------------------------------------------------------------------------

/// Summary of today's habit completion progress.
class DailyProgress {
  const DailyProgress({
    required this.completedCount,
    required this.totalCount,
  });

  final int completedCount;
  final int totalCount;

  /// Completion percentage as 0.0–1.0.
  double get percentage =>
      totalCount == 0 ? 0.0 : (completedCount / totalCount).clamp(0.0, 1.0);

  bool get allDone => totalCount > 0 && completedCount >= totalCount;
  bool get noneDone => completedCount == 0;
  bool get isEmpty => totalCount == 0;

  int get remaining => (totalCount - completedCount).clamp(0, totalCount);
}

// ---------------------------------------------------------------------------
// Heatmap
// ---------------------------------------------------------------------------

/// Completion data for a single calendar day (heatmap cell).
class DayCompletion {
  const DayCompletion({
    required this.date,
    required this.completionPercentage,
    this.isRecoveryDay = false,
  });

  final DateTime date;

  /// 0.0 (no completion) to 1.0 (all habits completed).
  final double completionPercentage;

  /// Whether this was a streak forgiveness recovery day.
  final bool isRecoveryDay;

  /// Heatmap intensity bucket 0–4 (maps to AppColors.heatmap[index]).
  int get heatmapLevel {
    if (completionPercentage == 0) return 0;
    if (completionPercentage < 0.25) return 1;
    if (completionPercentage < 0.50) return 2;
    if (completionPercentage < 0.75) return 3;
    return 4;
  }
}

// ---------------------------------------------------------------------------
// Recent activity
// ---------------------------------------------------------------------------

/// A completion record paired with the habit name for display.
class CompletionWithHabit {
  const CompletionWithHabit({
    required this.completionId,
    required this.habitId,
    required this.habitName,
    required this.habitEmoji,
    required this.completedAt,
    required this.completedDate,
  });

  final int completionId;
  final int habitId;
  final String habitName;
  final String habitEmoji;
  final DateTime completedAt;
  final DateTime completedDate;
}

// ---------------------------------------------------------------------------
// Streak
// ---------------------------------------------------------------------------

/// Streak data for a habit or overall across all habits.
class StreakData {
  const StreakData({
    required this.currentStreak,
    required this.longestStreak,
    this.lastCompletedDate,
  });

  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCompletedDate;

  /// True if the current streak equals or exceeds the longest ever.
  bool get isPersonalBest =>
      currentStreak > 0 && currentStreak >= longestStreak;
}

// ---------------------------------------------------------------------------
// Statistics — DailyCompletion (trend chart data point)
// ---------------------------------------------------------------------------

/// A single date's overall completion percentage for the trend chart.
class DailyCompletion {
  const DailyCompletion({
    required this.date,
    required this.percentage,
  });

  final DateTime date;

  /// 0.0 to 1.0 (fraction of habits completed that day).
  final double percentage;
}

// ---------------------------------------------------------------------------
// Statistics — HabitBreakdown (per-habit analytics)
// ---------------------------------------------------------------------------

/// Per-habit statistics for the breakdown list in Statistics.
class HabitBreakdown {
  const HabitBreakdown({
    required this.habitId,
    required this.name,
    required this.emoji,
    required this.categoryColorValue,
    required this.completionRate,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalCompletions,
  });

  final int habitId;
  final String name;
  final String emoji;
  final int categoryColorValue;

  /// 0.0–1.0 fraction of scheduled days completed (last 30 days).
  final double completionRate;

  final int currentStreak;
  final int longestStreak;
  final int totalCompletions;

  bool get isPersonalBest =>
      currentStreak > 0 && currentStreak >= longestStreak;
}

// ---------------------------------------------------------------------------
// Statistics — WeeklyInsight
// ---------------------------------------------------------------------------

/// Auto-generated weekly insight message for the insight card.
class WeeklyInsight {
  const WeeklyInsight({
    required this.message,
    required this.weeklyCompletionRate,
    this.mostConsistentDay,
    this.bestHabitName,
  });

  final String message;
  final double weeklyCompletionRate;

  /// e.g. "Wednesday"
  final String? mostConsistentDay;

  /// Habit name with highest completion this week
  final String? bestHabitName;
}

