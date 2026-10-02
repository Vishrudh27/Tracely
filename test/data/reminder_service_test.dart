import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/services/reminder_service.dart';

/// This is the one piece of the reminder feature that's actually testable —
/// scheduling, permissions, and the plugin itself need a real device/platform
/// channel and can't be unit tested.
void main() {
  group('daysUntilNextOccurrence', () {
    test('the target time is later today', () {
      final now = DateTime(2026, 3, 10, 7, 0);
      expect(daysUntilNextOccurrence(now, 8, 30), 0);
    });

    test('the target time already passed today', () {
      final now = DateTime(2026, 3, 10, 9, 0);
      expect(daysUntilNextOccurrence(now, 8, 30), 1);
    });

    test('exactly at the target time counts as already passed', () {
      // zonedSchedule with matchDateTimeComponents.time re-fires daily off
      // this instant, so "now == target" must roll to tomorrow — otherwise
      // it would fire again immediately for whoever sets it at 8:30 sharp.
      final now = DateTime(2026, 3, 10, 8, 30);
      expect(daysUntilNextOccurrence(now, 8, 30), 1);
    });

    test('one minute before the target time is still today', () {
      final now = DateTime(2026, 3, 10, 8, 29);
      expect(daysUntilNextOccurrence(now, 8, 30), 0);
    });
  });

  group('ReminderSettings.timeLabel', () {
    test('formats morning, noon, and midnight correctly', () {
      expect(
        const ReminderSettings(enabled: true, hour: 8, minute: 30).timeLabel,
        '8:30 AM',
      );
      expect(
        const ReminderSettings(enabled: true, hour: 12, minute: 0).timeLabel,
        '12:00 PM',
      );
      expect(
        const ReminderSettings(enabled: true, hour: 0, minute: 5).timeLabel,
        '12:05 AM',
      );
      expect(
        const ReminderSettings(enabled: true, hour: 23, minute: 59).timeLabel,
        '11:59 PM',
      );
    });
  });

  group('notification ids', () {
    test('habit ids are unique, never 0, and below every task id', () {
      final seen = <int>{};
      for (var h = 1; h <= 1000; h++) {
        for (var slot = 0; slot < 8; slot++) {
          final id = habitNotificationId(h, slot);
          expect(id, isNot(0));
          expect(id, lessThan(taskNotificationId(1)));
          expect(seen.add(id), isTrue, reason: 'habit $h slot $slot');
        }
      }
    });
  });

  group('daysUntilNextWeekday', () {
    // 2026-03-09 is a Monday.
    test('same weekday, before the time → today', () {
      expect(daysUntilNextWeekday(DateTime(2026, 3, 9, 7), 1, 8, 0), 0);
    });
    test('same weekday, at or after the time → next week', () {
      expect(daysUntilNextWeekday(DateTime(2026, 3, 9, 8), 1, 8, 0), 7);
      expect(daysUntilNextWeekday(DateTime(2026, 3, 9, 9), 1, 8, 0), 7);
    });
    test('Mon → Fri is 4, Sun → Mon is 1', () {
      expect(daysUntilNextWeekday(DateTime(2026, 3, 9, 9), 5, 8, 0), 4);
      expect(daysUntilNextWeekday(DateTime(2026, 3, 15, 23), 1, 8, 0), 1);
    });
  });

  group('taskReminderAt', () {
    final now = DateTime(2026, 3, 10, 12, 0);
    test('missing date or time → null', () {
      expect(taskReminderAt(null, '18:00', now), isNull);
      expect(taskReminderAt(DateTime(2026, 3, 10), null, now), isNull);
    });
    test('past or exactly now → null', () {
      expect(taskReminderAt(DateTime(2026, 3, 10), '11:59', now), isNull);
      expect(taskReminderAt(DateTime(2026, 3, 10), '12:00', now), isNull);
      expect(taskReminderAt(DateTime(2026, 3, 9), '18:00', now), isNull);
    });
    test('future → that moment', () {
      expect(
        taskReminderAt(DateTime(2026, 3, 10), '18:30', now),
        DateTime(2026, 3, 10, 18, 30),
      );
    });
  });
}
