import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/voice_command_parser.dart';

void main() {
  // Wednesday.
  final today = DateTime(2026, 9, 23);
  final tomorrow = DateTime(2026, 9, 24);
  final yesterday = DateTime(2026, 9, 22);

  VoiceCommand parse(String s, {int nowMinute = 600}) =>
      parseVoiceCommand(s, today: today, nowMinute: nowMinute);

  group('createHabit', () {
    final cases = <String, (String, String, List<int>, int?)>{
      'add running every morning at 6': ('Running', 'daily', [], 360),
      'Add read 20 pages on weekdays': ('Read 20 pages', 'specific_days', [1, 2, 3, 4, 5], null),
      'new habit meditate every Monday and Wednesday at 7 pm': ('Meditate', 'specific_days', [1, 3], 1140),
      'add stretching on weekends at 9:30 a.m.': ('Stretching', 'specific_days', [6, 7], 570),
      'create a habit to drink water daily': ('Drink water', 'daily', [], null),
      'add journaling every night at 10': ('Journaling', 'daily', [], 1320),
      'add walk at noon': ('Walk', 'daily', [], 720),
      'add yoga 7 in the evening': ('Yoga', 'daily', [], 1140),
      'add running at six thirty': ('Running', 'daily', [], 1110),
      'i want to add running': ('Running', 'daily', [], null),
      'add evening walk at 7pm': ('Evening walk', 'daily', [], 1140),
      'add gym on monday, wednesday and friday at 6:30 am': ('Gym', 'specific_days', [1, 3, 5], 390),
    };
    cases.forEach((input, expected) {
      test(input, () {
        final c = parse(input);
        expect(c.intent, VoiceIntent.createHabit);
        expect(c.text, expected.$1);
        expect(c.frequencyType, expected.$2);
        expect(c.specificDays, expected.$3);
        expect(c.minuteOfDay, expected.$4);
      });
    });
  });

  group('createReminderTask', () {
    final cases = <(String, int), (String, int?, DateTime)>{
      ('remind me to study at 9 PM', 600): ('Study', 1260, today),
      ('remind me to study at 9 PM', 1330): ('Study', 1260, tomorrow),
      ('remind me to call mom tomorrow at 6:30', 600): ('Call mom', 1110, tomorrow),
      ('remind me to pay rent on Friday', 600): ('Pay rent', null, DateTime(2026, 9, 25)),
      ('remind me to stretch at 9', 600): ('Stretch', 1260, today),
      ('remind me to buy milk', 600): ('Buy milk', null, today),
      ('remind me to take meds tonight at 8', 600): ('Take meds', 1200, today),
      ('Remind me to study at 9 p.m.', 600): ('Study', 1260, today),
      ('remind me to water plants on wednesday at 8 am', 900): ('Water plants', 480, DateTime(2026, 9, 30)),
    };
    cases.forEach((input, expected) {
      test('${input.$1} @${input.$2}', () {
        final c = parse(input.$1, nowMinute: input.$2);
        expect(c.intent, VoiceIntent.createReminderTask);
        expect(c.text, expected.$1);
        expect(c.minuteOfDay, expected.$2);
        expect(c.date, expected.$3);
      });
    });
  });

  group('completeHabit', () {
    final cases = {
      'mark meditation as done': 'meditation',
      'I did my workout': 'my workout',
      'done with reading': 'reading',
      'reading done': 'reading',
      'I ran today': 'ran',
      'finished my run for today': 'my run',
    };
    cases.forEach((input, phrase) {
      test(input, () {
        final c = parse(input);
        expect(c.intent, VoiceIntent.completeHabit);
        expect(c.text, phrase);
      });
    });
  });

  group('logMiss', () {
    final cases = <String, (String, DateTime, String?, String?)>{
      'I missed my workout because I was tired': ('my workout', today, 'low_energy', 'tired'),
      'skipped running yesterday, too busy': ('running', yesterday, 'too_busy', 'too busy'),
      'I was sick so I skipped the gym': ('the gym', today, 'felt_sick', 'sick'),
      'forgot to meditate': ('meditate', today, 'forgot', null),
      'skipped my run because it was too cold': ('my run', today, 'weather', 'too cold'),
      'missed reading because my cat sat on my laptop': ('reading', today, null, 'my cat sat on my laptop'),
      'I missed yoga': ('yoga', today, null, null),
    };
    cases.forEach((input, expected) {
      test(input, () {
        final c = parse(input);
        expect(c.intent, VoiceIntent.logMiss);
        expect(c.text, expected.$1);
        expect(c.date, expected.$2);
        expect(c.reasonKey, expected.$3);
        expect(c.reasonText, expected.$4);
      });
    });
  });

  test('unknown', () {
    expect(parse("what's the weather").intent, VoiceIntent.unknown);
    expect(parse('').intent, VoiceIntent.unknown);
    expect(parse('   ').intent, VoiceIntent.unknown);
    expect(parse('add').intent, VoiceIntent.unknown);
  });

  group('bestNameMatches', () {
    List<String> match(String q, List<String> names) =>
        bestNameMatches(q, names, (n) => n);

    test('cases', () {
      expect(match('my workout', ['Workout', 'Read 20 pages']), ['Workout']);
      expect(match('work out', ['Workout']), ['Workout']);
      expect(match('ran', ['Morning run']), ['Morning run']);
      expect(match('meditation', ['Meditate']), ['Meditate']);
      expect(match('reading', ['Read', 'Read 20 pages']), ['Read']);
      expect(match('read', ['Read news', 'Read book']),
          unorderedEquals(['Read news', 'Read book']));
      expect(match('swim', ['Workout']), isEmpty);
      expect(match('', ['Workout']), isEmpty);
    });
  });

  test('suggestCategoryName', () {
    expect(suggestCategoryName('Running'), 'Fitness');
    expect(suggestCategoryName('Read 20 pages'), 'Learning');
    expect(suggestCategoryName('Meditate'), 'Mind');
    expect(suggestCategoryName('Drink water'), 'Health');
    expect(suggestCategoryName('Call mom'), 'Social');
    expect(suggestCategoryName('Paint'), 'Creativity');
    expect(suggestCategoryName('Skincare'), 'Self-Care');
    expect(suggestCategoryName('Xyz'), isNull);
  });

  test('reasonKeyFor', () {
    expect(reasonKeyFor('had a deadline at work'), 'unexpected_work');
    expect(reasonKeyFor('it was raining'), 'weather');
    expect(reasonKeyFor('too cold'), 'weather');
    expect(reasonKeyFor('caught a cold'), 'felt_sick');
    expect(reasonKeyFor('my workout'), isNull);
  });
}
