import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/services/reflection_gate_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReflectionDao', () {
    late AppDatabase db;
    late int habitA;
    late int habitB;

    final missedOn = DateTime(2026, 9, 16);

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final categoryId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Health',
              emoji: '💚',
              colorValue: 0xFF65A30D,
            ),
          );
      habitA = await db.habitDao.insertHabit(
        HabitsCompanion.insert(name: 'Walk', categoryId: categoryId),
      );
      habitB = await db.habitDao.insertHabit(
        HabitsCompanion.insert(name: 'Read', categoryId: categoryId),
      );
    });

    tearDown(() async => db.close());

    test('several missed habits can be reflected on in one day', () async {
      // Two missed habits write two rows for the same day. The day-gate used
      // to read these back with getSingleOrNull and threw StateError, which
      // surfaced as an unhandled error on every later dashboard open.
      await db.reflectionDao.createHabitReflection(
        habitId: habitA,
        missedDate: missedOn,
        reason: 'low_energy',
      );
      await db.reflectionDao.createHabitReflection(
        habitId: habitB,
        missedDate: missedOn,
        reason: 'too_busy',
      );

      final rows = await db.select(db.habitReflections).get();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.habitId), containsAll(<int>[habitA, habitB]));
    });

    test('each reason is stored as its own row so counts group correctly',
        () async {
      for (final reason in ['low_energy', 'too_busy']) {
        await db.reflectionDao.createHabitReflection(
          habitId: habitA,
          missedDate: missedOn,
          reason: reason,
        );
      }

      final reasons = await db.reflectionDao.watchMostCommonReasons().first;

      expect(
        reasons.map((r) => r.reason),
        containsAll(<String>['low_energy', 'too_busy']),
        reason: 'a joined "low_energy,too_busy" key would render as Other',
      );
      expect(reasons.every((r) => r.count == 1), isTrue);
    });

    test('free-text reason is persisted rather than discarded', () async {
      await db.reflectionDao.createHabitReflection(
        habitId: habitA,
        missedDate: missedOn,
        reason: 'custom',
        followUpAnswer: 'power cut all evening',
      );

      final rows = await db.select(db.habitReflections).get();

      expect(rows.single.reason, 'custom');
      expect(rows.single.followUpAnswer, 'power cut all evening');
    });

    test('the same reason twice for one habit and day is not duplicated',
        () async {
      for (var i = 0; i < 2; i++) {
        await db.reflectionDao.createHabitReflection(
          habitId: habitA,
          missedDate: missedOn,
          reason: 'forgot',
        );
      }

      final rows = await db.select(db.habitReflections).get();
      expect(rows, hasLength(1));
    });

    test('different reasons for one habit and day are both kept', () async {
      await db.reflectionDao.createHabitReflection(
        habitId: habitA,
        missedDate: missedOn,
        reason: 'forgot',
      );
      await db.reflectionDao.createHabitReflection(
        habitId: habitA,
        missedDate: missedOn,
        reason: 'traveling',
      );

      final rows = await db.select(db.habitReflections).get();
      expect(rows, hasLength(2));
    });
  });

  group('ReflectionGateService', () {
    test('the ritual is offered on the first open of the day, at any hour',
        () async {
      SharedPreferences.setMockInitialValues({});

      // Previously this returned false whenever the clock read 12:00 or later,
      // so an afternoon-only day showed no ritual and therefore no quote.
      await expectLater(
        ReflectionGateService.shouldShowReflection(),
        completion(isTrue),
      );
    });

    test('the ritual is not offered twice on the same day', () async {
      SharedPreferences.setMockInitialValues({});

      await ReflectionGateService.markShown();

      await expectLater(
        ReflectionGateService.shouldShowReflection(),
        completion(isFalse),
      );
    });

    test('a stale mark from another day does not suppress the ritual',
        () async {
      SharedPreferences.setMockInitialValues({
        'flutter.reflection_gate_shown_date': '2020-01-01',
      });

      await expectLater(
        ReflectionGateService.shouldShowReflection(),
        completion(isTrue),
      );
    });

    test('Pause & Reflect is gated once a day even when dismissed', () async {
      SharedPreferences.setMockInitialValues({});

      await expectLater(
        ReflectionGateService.shouldShowPauseAndReflect(),
        completion(isTrue),
      );

      // Marked when the sheet is presented, so "Not now" — which writes no
      // reflection row — still consumes the day's prompt.
      await ReflectionGateService.markPauseAndReflectShown();

      await expectLater(
        ReflectionGateService.shouldShowPauseAndReflect(),
        completion(isFalse),
      );
    });

    test('the two gates are independent', () async {
      SharedPreferences.setMockInitialValues({});

      await ReflectionGateService.markShown();

      expect(await ReflectionGateService.shouldShowReflection(), isFalse);
      expect(await ReflectionGateService.shouldShowPauseAndReflect(), isTrue);
    });
  });
}
