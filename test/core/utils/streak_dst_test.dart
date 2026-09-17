import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/extensions/date_extensions.dart';
import 'package:habit_tracker/core/utils/streak_calculator.dart';

/// Regression tests for streaks across a daylight-saving transition.
///
/// Streak logic used `difference(...).inDays`, which counts elapsed hours. The
/// local day containing a spring-forward is only 23 hours long, so two
/// genuinely consecutive days measured 0 days apart and the streak silently
/// truncated.
///
/// Run under a DST-observing zone to exercise the real path:
///   TZ=America/New_York flutter test test/core/utils/streak_dst_test.dart
///
/// The assertions hold in any zone; they only *catch* the old bug in one that
/// observes DST.
void main() {
  group('DST transitions', () {
    // US spring-forward 2026: clocks jump 02:00 -> 03:00 on Sunday 8 March.
    final springForward = [
      DateTime(2026, 3, 7),
      DateTime(2026, 3, 8),
      DateTime(2026, 3, 9),
      DateTime(2026, 3, 10),
    ];

    // US fall-back 2026: clocks drop 02:00 -> 01:00 on Sunday 1 November.
    final fallBack = [
      DateTime(2026, 10, 31),
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 2),
      DateTime(2026, 11, 3),
    ];

    test('longestStreak counts every day across a spring-forward', () {
      expect(StreakCalculator.longestStreak(springForward), 4);
    });

    test('longestStreak counts every day across a fall-back', () {
      expect(StreakCalculator.longestStreak(fallBack), 4);
    });

    test('calendarDaysSince measures calendar days, not elapsed hours', () {
      expect(DateTime(2026, 3, 9).calendarDaysSince(DateTime(2026, 3, 8)), 1);
      expect(DateTime(2026, 11, 2).calendarDaysSince(DateTime(2026, 11, 1)), 1);
      expect(DateTime(2026, 3, 10).calendarDaysSince(DateTime(2026, 3, 7)), 3);
    });

    test('addDays stays at local midnight across a transition', () {
      final afterSpring = DateTime(2026, 3, 7).addDays(2);
      expect(afterSpring, DateTime(2026, 3, 9));
      expect(afterSpring.hour, 0);

      final afterFall = DateTime(2026, 10, 31).addDays(2);
      expect(afterFall, DateTime(2026, 11, 2));
      expect(afterFall.hour, 0);
    });
  });

  group('year boundary', () {
    test('calendarDaysSince spans new year', () {
      expect(DateTime(2026, 1, 1).calendarDaysSince(DateTime(2025, 12, 31)), 1);
    });
  });
}
