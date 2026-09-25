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
}
