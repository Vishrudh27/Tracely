import '../constants/quote_constants.dart';

/// Time-based greeting utilities.
///
/// Extracted from AnimatedGreeting so the logic is testable and reusable
/// across Dashboard and any other screen that needs a greeting.
final class GreetingUtils {
  GreetingUtils._();

  /// Returns a time-appropriate greeting string.
  ///
  /// - Before noon → "Good Morning"
  /// - Noon to 17:00 → "Good Afternoon"
  /// - 17:00 onward → "Good Evening"
  static String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  /// Returns a warm, context-aware subtitle based on time of day and streak.
  ///
  /// [currentStreak] — the user's current habit streak in days.
  /// Pass 0 if no streak data is available.
  static String dashboardSubtitle({int currentStreak = 0}) {
    final hour = DateTime.now().hour;

    if (currentStreak >= 7) {
      return "You're on a roll — $currentStreak days strong.";
    }

    if (currentStreak == 1) {
      return 'Day one — the hardest and most important.';
    }

    if (hour < 10) {
      return 'Fresh start ahead.';
    }

    if (hour < 17) {
      return 'Still time to make today count.';
    }

    return "How's today been?";
  }

  /// Returns the daily motivation footer text for a given day.
  ///
  /// Deterministically selected by day-of-year so it changes each day
  /// but stays the same within a day.
  static String motivationFooter(List<String> pool, [DateTime? date]) {
    if (pool.isEmpty) return '';
    final index = QuoteConstants.dayOfYear(date ?? DateTime.now());
    return pool[index % pool.length];
  }
}
