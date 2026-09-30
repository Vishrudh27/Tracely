import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/extensions/date_extensions.dart';
import 'package:habit_tracker/core/utils/streak_calculator.dart';

void main() {
  // Helper to build a date at midnight for a given offset from today.
  DateTime day(int daysAgo) =>
      DateTime.now()
          .subtract(Duration(days: daysAgo))
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);

  group('StreakCalculator.currentStreak', () {
    test('returns 0 for empty list', () {
      expect(StreakCalculator.currentStreak([]), 0);
    });

    test('returns 1 when only today is completed', () {
      expect(StreakCalculator.currentStreak([day(0)]), 1);
    });

    test('returns 1 when only yesterday is completed', () {
      expect(StreakCalculator.currentStreak([day(1)]), 1);
    });

    test('returns 0 when last completion was 2+ days ago (streak broken)', () {
      expect(StreakCalculator.currentStreak([day(2)]), 0);
      expect(StreakCalculator.currentStreak([day(5)]), 0);
    });

    test('counts consecutive days ending today', () {
      // Today, yesterday, day before = 3-day streak
      final dates = [day(2), day(1), day(0)];
      expect(StreakCalculator.currentStreak(dates), 3);
    });

    test('counts consecutive days ending yesterday', () {
      // Yesterday, day before, 3 days ago = 3-day streak (still alive)
      final dates = [day(3), day(2), day(1)];
      expect(StreakCalculator.currentStreak(dates), 3);
    });

    test('stops counting at gap', () {
      // Today, yesterday, skip one day, then 3 more
      final dates = [day(5), day(4), day(3), day(1), day(0)];
      expect(StreakCalculator.currentStreak(dates), 2);
    });

    test('handles unsorted input', () {
      // Out of order — should still compute correctly
      final dates = [day(0), day(2), day(1)];
      expect(StreakCalculator.currentStreak(dates), 3);
    });

    test('handles duplicate dates', () {
      final dates = [day(0), day(0), day(1), day(1)];
      expect(StreakCalculator.currentStreak(dates), 2);
    });

    test('handles month boundary correctly', () {
      // Construct a streak that crosses a month boundary
      // e.g. Jan 31, Feb 1 (or use relative days to be safe)
      final jan31 = DateTime(2025, 1, 31);
      final feb1 = DateTime(2025, 2, 1);
      final feb2 = DateTime(2025, 2, 2);

      // Only works as a current streak if these dates are recent enough.
      // For longestStreak we can test month boundaries reliably.
      expect(StreakCalculator.longestStreak([jan31, feb1, feb2]), 3);
    });

    test('handles year boundary correctly', () {
      final dec31 = DateTime(2024, 12, 31);
      final jan1 = DateTime(2025, 1, 1);
      expect(StreakCalculator.longestStreak([dec31, jan1]), 2);
    });
  });

  group('StreakCalculator.longestStreak', () {
    test('returns 0 for empty list', () {
      expect(StreakCalculator.longestStreak([]), 0);
    });

    test('returns 1 for a single date', () {
      expect(StreakCalculator.longestStreak([DateTime(2025, 3, 15)]), 1);
    });

    test('finds longest streak in the middle of data', () {
      // 2 consecutive, gap, 4 consecutive, gap, 1 isolated
      final dates = [
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 2),
        // gap
        DateTime(2025, 1, 5),
        DateTime(2025, 1, 6),
        DateTime(2025, 1, 7),
        DateTime(2025, 1, 8),
        // gap
        DateTime(2025, 1, 15),
      ];
      expect(StreakCalculator.longestStreak(dates), 4);
    });

    test('handles all consecutive days', () {
      final dates = List.generate(
        10,
        (i) => DateTime(2025, 3, 1 + i),
      );
      expect(StreakCalculator.longestStreak(dates), 10);
    });

    test('handles all isolated days (no streak)', () {
      final dates = [
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 3),
        DateTime(2025, 1, 5),
        DateTime(2025, 1, 7),
      ];
      expect(StreakCalculator.longestStreak(dates), 1);
    });

    test('handles duplicate dates', () {
      final dates = [
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 2),
        DateTime(2025, 1, 2),
        DateTime(2025, 1, 3),
      ];
      expect(StreakCalculator.longestStreak(dates), 3);
    });
  });

  group('StreakCalculator with isScheduled (rest days don\'t break it)', () {
    // Only Mon–Fri (ISO weekday 1-5) is scheduled.
    bool weekdaysOnly(DateTime d) => d.weekday <= 5;

    test('an unscheduled rest day between the last completion and today '
        'does not break currentStreak, though it would by default', () {
      // Last completion was 2 days ago — normally dead (see the "returns 0
      // when last completion was 2+ days ago" test above). day(1), the day
      // in between, is deterministically treated as a rest day here, so this
      // doesn't depend on what the real calendar day happens to be.
      final dates = [day(3), day(2)];
      expect(StreakCalculator.currentStreak(dates), 0); // unchanged default

      final streak = StreakCalculator.currentStreak(
        dates,
        isScheduled: (d) => !d.isSameDay(day(1)),
      );
      expect(streak, 2);
    });

    test('longestStreak treats a weekend gap as continuous', () {
      // Fri Jan 2, then Mon Jan 5 2026 — Sat/Sun between are rest days.
      final dates = [DateTime(2026, 1, 2), DateTime(2026, 1, 5)];
      expect(
        StreakCalculator.longestStreak(dates, isScheduled: weekdaysOnly),
        2,
      );
      // Without schedule awareness, the same gap breaks the streak.
      expect(StreakCalculator.longestStreak(dates), 1);
    });

    test('a missed scheduled weekday still breaks the streak', () {
      // Mon, (missed Tue), Wed — Tue was scheduled and skipped.
      final dates = [DateTime(2026, 1, 5), DateTime(2026, 1, 7)];
      expect(
        StreakCalculator.longestStreak(dates, isScheduled: weekdaysOnly),
        1,
      );
    });

    test('default (no isScheduled) behaves exactly as before', () {
      final dates = [DateTime(2026, 1, 1), DateTime(2026, 1, 2)];
      expect(StreakCalculator.longestStreak(dates), 2);
    });
  });

  group('StreakCalculator.completionRate', () {
    test('returns 0 when totalDays is 0', () {
      expect(StreakCalculator.completionRate(0, 0), 0.0);
    });

    test('returns correct rate', () {
      expect(StreakCalculator.completionRate(7, 10), 0.7);
    });

    test('clamps to 1.0 when completed > total', () {
      expect(StreakCalculator.completionRate(12, 10), 1.0);
    });
  });

  group('StreakCalculator.needsCompletionToday', () {
    test('returns true for empty list', () {
      expect(StreakCalculator.needsCompletionToday([]), true);
    });

    test('returns false when today is completed', () {
      expect(StreakCalculator.needsCompletionToday([day(0)]), false);
    });

    test('returns true when last completion was yesterday', () {
      expect(StreakCalculator.needsCompletionToday([day(1)]), true);
    });
  });
}
