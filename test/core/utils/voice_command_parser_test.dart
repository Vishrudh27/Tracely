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

  group('broken English → createHabit', () {
    final cases = <String, (String, String, List<int>, int?)>{
      'add the habit of reading': ('Reading', 'daily', [], null),
      'Add the habit of reading every day at 9 pm': ('Reading', 'daily', [], 1260),
      // Two recognizer segments joined by the sheet.
      'add the habit of reading. Every day at 9 p.m.': ('Reading', 'daily', [], 1260),
      'i wanna add new habit reading daily 9pm': ('Reading', 'daily', [], 1260),
      'make a habit to drink water every day': ('Drink water', 'daily', [], null),
      'pls add gym evry mon wed fri morning 6': ('Gym', 'specific_days', [1, 3, 5], 360),
      'reading habit daily 8 pm': ('Reading', 'daily', [], 1200),
      'daily morning 6 am running': ('Running', 'daily', [], 360),
      'start doing yoga at 7 in the morning': ('Yoga', 'daily', [], 420),
      'add yoga mon to fri': ('Yoga', 'specific_days', [1, 2, 3, 4, 5], null),
      'add meditation at half past six in the morning': ('Meditation', 'daily', [], 390),
      'add walk at 7.30 pm': ('Walk', 'daily', [], 1170),
      'add walking every evening 2 rounds': ('Walking 2 rounds', 'daily', [], null),
      // Saying "habit" wins over a start day.
      'add the habit of reading from tomorrow': ('Reading', 'daily', [], null),
      'add the habit of reading today': ('Reading', 'daily', [], null),
      'reading habit tomorrow onwards': ('Reading', 'daily', [], null),
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

  group('broken English → createReminderTask', () {
    final cases = <String, (String, int?, DateTime)>{
      'remind me tmrw 6 pm call mom': ('Call mom', 1080, tomorrow),
      'remainder for pay bill tomorrow': ('Pay bill', null, tomorrow),
      'add task buy milk': ('Buy milk', null, today),
      'add buy milk to my tasks': ('Buy milk', null, today),
      'add call mom tomorrow': ('Call mom', null, tomorrow),
      'call mom tomorrow at 6': ('Call mom', 1080, tomorrow),
      "don't forget to drink water at 4 pm": ('Drink water', 960, today),
      'remind me at 6 to call mom': ('Call mom', 1080, today),
      'alert me to drink water at 4': ('Drink water', 960, today),
      // Everyday verbs stay out of delete / habit.
      'drop kids at school tomorrow': ('Drop kids at school', null, tomorrow),
      'make tea at 6': ('Make tea', 1080, today),
      'take out the trash tomorrow': ('Take out the trash', null, tomorrow),
      // Compound sentence: drop the "and set a reminder" clause and the
      // stray second date; keep title, time, first date.
      'add the task to complete the assignment and set a reminder at today and also tomorrow at 10:39 pm':
          ('Complete the assignment', 1359, today),
    };
    cases.forEach((input, expected) {
      test(input, () {
        final c = parse(input);
        expect(c.intent, VoiceIntent.createReminderTask);
        expect(c.text, expected.$1);
        expect(c.minuteOfDay, expected.$2);
        expect(c.date, expected.$3);
      });
    });
  });

  group('broken English → completeHabit', () {
    final cases = {
      'i done reading': 'reading',
      'reading completed today': 'reading',
      'today i have complete my workout': 'my workout',
      'completed my reading': 'my reading',
      'finish meditation': 'meditation',
      'i am done with reading': 'reading',
      'just did my workout': 'my workout',
      'workout is over': 'workout',
      'I went for a run': 'a run',
    };
    cases.forEach((input, phrase) {
      test(input, () {
        final c = parse(input);
        expect(c.intent, VoiceIntent.completeHabit);
        expect(c.text, phrase);
      });
    });
  });

  group('broken English → logMiss', () {
    final cases = <String, (String, DateTime, String?, String?)>{
      'reading not done because busy': ('reading', today, 'too_busy', 'busy'),
      'i not did my workout bcoz tired': ('my workout', today, 'low_energy', 'tired'),
      'i was not able to go gym because of rain': ('go gym', today, 'weather', 'rain'),
      'couldnt do yoga yesterday, not feeling well':
          ('yoga', yesterday, 'felt_sick', 'not feeling well'),
      // "sat" is a verb here, not Saturday.
      'my cat sat on my laptop so i skipped reading':
          ('reading', today, null, 'my cat sat on my laptop'),
      // No miss verb, but a reason word → a miss, not a completion.
      'i was tired to the vessel': ('Vessel', today, 'low_energy', null),
      'i was sick today reading': ('Reading', today, 'felt_sick', null),
      // "to do" is an infinitive, "habit" is incidental — still a miss.
      'i was tired to do the vessel habit': ('Vessel', today, 'low_energy', null),
      'i was too tired to do reading': ('Reading', today, 'low_energy', null),
      // No ASR space between "i" and "am" — must still read as "i am".
      'iam tired to the vessel': ('Vessel', today, 'low_energy', null),
      // No specific habit named ("the habit" is generic) — still a miss,
      // with an empty name so the card offers every habit to pick from,
      // instead of silently creating a habit called "I am tired".
      'iam tired to the habit': ('', today, 'low_energy', null),
      'i am tired to the habit': ('', today, 'low_energy', null),
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

  group('deleteItem', () {
    final cases = <String, (String, String?)>{
      'delete the reading habit': ('Reading', 'habit'),
      'remove task buy milk': ('Buy milk', 'task'),
      'cancel my reminder to call mom': ('Call mom', 'task'),
      'delete workout': ('Workout', null),
      'dlt reading from my habits': ('Reading', 'habit'),
      'reading habit delete': ('Reading', 'habit'),
      'get rid of the meditation habit': ('Meditation', 'habit'),
    };
    cases.forEach((input, expected) {
      test(input, () {
        final c = parse(input);
        expect(c.intent, VoiceIntent.deleteItem);
        expect(c.text, expected.$1);
        expect(c.target, expected.$2);
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
      expect(match('meditaton', ['Meditation']), ['Meditation']);
      // One letter apart, but short words must not fuzzy-match.
      expect(match('talk', ['Walk']), isEmpty);
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

  test('learnedCategoryId follows the user’s own habits', () {
    const mind = 1, fitness = 2, creativity = 3;
    // A correction for a word no keyword knows.
    expect(learnedCategoryId('Juggling', [('Juggling', creativity)]), creativity);
    expect(
      learnedCategoryId('Juggling practice', [('Morning juggling', creativity)]),
      creativity,
    );
    // Shared time-of-day words carry no meaning.
    expect(learnedCategoryId('Evening journaling', [('Evening walk', fitness)]), isNull);
    // …and neither do everyday verbs.
    expect(learnedCategoryId('Take a walk', [('Take vitamins', mind)]), isNull);
    expect(learnedCategoryId('Practice coding', [('Practice guitar', creativity)]), isNull);
    // Half the topic words is enough; less is not.
    expect(learnedCategoryId('Yoga at home', [('Yoga', mind)]), mind);
    expect(learnedCategoryId('Yoga with weights outside', [('Yoga', mind)]), isNull);
    // Earlier examples win ties (most recently edited habit first).
    expect(learnedCategoryId('Yoga', [('Yoga', mind), ('Yoga', fitness)]), mind);
    expect(learnedCategoryId('Paint', [('Juggling', creativity)]), isNull);
  });

  test('reasonKeyFor', () {
    expect(reasonKeyFor('had a deadline at work'), 'unexpected_work');
    expect(reasonKeyFor('it was raining'), 'weather');
    expect(reasonKeyFor('too cold'), 'weather');
    expect(reasonKeyFor('caught a cold'), 'felt_sick');
    expect(reasonKeyFor('my workout'), isNull);
  });
}
