import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/behavior_insights.dart';

void main() {
  final today = DateTime(2026, 9, 23);

  /// One completion per day going back from today, at the given times.
  List<DateTime> at(List<String> hhmm, {int startDaysAgo = 0}) => [
        for (var i = 0; i < hhmm.length; i++)
          DateTime(
            today.year,
            today.month,
            today.day - startDaysAgo - i,
            int.parse(hhmm[i].split(':')[0]),
            int.parse(hhmm[i].split(':')[1]),
          ),
      ];

  final tight = at(['18:20', '18:25', '18:30', '18:35', '18:40', '18:30']);

  group('usualCompletionMinute', () {
    test('tight samples → median', () {
      expect(
        usualCompletionMinute(
          at(['18:20', '18:25', '18:30', '18:35', '18:40']),
          today: today,
        ),
        18 * 60 + 30,
      );
    });

    test('fewer than 5 samples → null', () {
      expect(
        usualCompletionMinute(at(['18:20', '18:25', '18:30', '18:35']),
            today: today),
        isNull,
      );
    });

    test('scattered times → null', () {
      expect(
        usualCompletionMinute(
          at(['07:00', '10:00', '13:00', '16:00', '19:00', '21:00']),
          today: today,
        ),
        isNull,
      );
    });

    test('samples older than 30 days are ignored', () {
      final old = at(['18:20', '18:25', '18:30', '18:35', '18:40'],
          startDaysAgo: 30);
      expect(usualCompletionMinute(old, today: today), isNull);
    });

    test('midnight wrap stays silent rather than wrong', () {
      expect(
        usualCompletionMinute(
          at(['23:50', '00:10', '23:55', '00:05', '23:45', '00:15']),
          today: today,
        ),
        isNull,
      );
    });
  });

  group('pickBehaviorInsight', () {
    HabitTimingInput habit({int? reminder, int energyMisses = 0, int id = 1}) =>
        HabitTimingInput(
          habitId: id,
          name: 'Run',
          reminderMinute: reminder,
          completedAts: tight,
          energyMisses: energyMisses,
        );

    test('drift under an hour → nothing', () {
      expect(
        pickBehaviorInsight([habit(reminder: 18 * 60 + 30 + 45)],
            today: today, dismissed: {}),
        isNull,
      );
    });

    test('drift of 75 min → move-reminder suggestion', () {
      final i = pickBehaviorInsight([habit(reminder: 19 * 60 + 45)],
          today: today, dismissed: {})!;
      expect(i.key, 'drift:1:18:30');
      expect(i.suggestedMinute, 18 * 60 + 30);
      expect(i.message, contains('6:30 PM'));
    });

    test('tired misses at a late reminder beat plain drift', () {
      final i = pickBehaviorInsight(
        [habit(reminder: 21 * 60, energyMisses: 3)],
        today: today,
        dismissed: {},
      )!;
      expect(i.key, 'miss:1:18:30');
      expect(i.suggestedMinute, 18 * 60 + 30);
    });

    test('a dismissed key falls through to the next candidate', () {
      final i = pickBehaviorInsight(
        [habit(reminder: 21 * 60, energyMisses: 3)],
        today: today,
        dismissed: {'miss:1:18:30'},
      )!;
      expect(i.key, 'drift:1:18:30');
    });

    test('no reminder → informational usual-time insight', () {
      final i = pickBehaviorInsight([habit()], today: today, dismissed: {})!;
      expect(i.key, 'usual:1');
      expect(i.suggestedMinute, isNull);
      expect(i.message, 'You usually complete Run around 6:30 PM.');
    });
  });
}
