import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/habit_schedule.dart';

void main() {
  // Wednesday.
  final today = DateTime(2026, 9, 23);
  final longAgo = DateTime(2020, 1, 1);

  /// The last [count] days that [keep] accepts, keyed at midnight.
  Set<DateTime> daysBack(int count, bool Function(DateTime day, int i) keep) {
    return {
      for (var i = 0; i < count; i++)
        if (keep(DateTime(today.year, today.month, today.day - i), i))
          DateTime(today.year, today.month, today.day - i),
    };
  }

  group('recentCompletionRate', () {
    test('a Mon–Fri habit done every weekday scores 100%', () {
      final weekdaysDone = daysBack(30, (d, _) => d.weekday <= 5);

      final rate = recentCompletionRate(
        frequencyType: 'specific_days',
        frequencyConfig: '[1,2,3,4,5]',
        today: today,
        createdDay: longAgo,
        completedDays: weekdaysDone,
      );

      expect(rate, 100);
    });

    test('the same habit scores 0% when only weekends were completed', () {
      final weekendsDone = daysBack(30, (d, _) => d.weekday > 5);

      final rate = recentCompletionRate(
        frequencyType: 'specific_days',
        frequencyConfig: '[1,2,3,4,5]',
        today: today,
        createdDay: longAgo,
        completedDays: weekendsDone,
      );

      expect(rate, 0);
    });

    test('a daily habit is scored against all 30 days', () {
      final halfDone = daysBack(30, (_, i) => i.isEven);

      final rate = recentCompletionRate(
        frequencyType: 'daily',
        frequencyConfig: null,
        today: today,
        createdDay: longAgo,
        completedDays: halfDone,
      );

      expect(rate, 50);
    });

    test('days before the habit existed are left out of the ratio', () {
      final createdDay = DateTime(today.year, today.month, today.day - 2);

      final rate = recentCompletionRate(
        frequencyType: 'daily',
        frequencyConfig: null,
        today: today,
        createdDay: createdDay,
        completedDays: {
          today,
          DateTime(today.year, today.month, today.day - 1),
          createdDay,
        },
      );

      expect(rate, 100);
    });

    test('a habit with no scheduled days yet reads 0, not a crash', () {
      final rate = recentCompletionRate(
        frequencyType: 'daily',
        frequencyConfig: null,
        today: today,
        createdDay: today.add(const Duration(days: 1)),
        completedDays: const {},
      );

      expect(rate, 0);
    });
  });

  group('isScheduledOn', () {
    test('a malformed config never hides the habit', () {
      expect(isScheduledOn('specific_days', 'not json', today), isTrue);
    });

    test('x_per_week counts every day until v0.2 handles it properly', () {
      expect(isScheduledOn('x_per_week', '{"count":3}', today), isTrue);
    });
  });
}
