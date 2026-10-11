import 'dart:convert';

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

    test('several missed habits can be reflected on in one day (one row per day)', () async {
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
      expect(rows, hasLength(1));
      final reflectedIds = await db.reflectionDao.getReflectedHabitIds(missedOn);
      expect(reflectedIds, containsAll(<int>[habitA, habitB]));
    });

    test('each reason is tallied so counts group correctly', () async {
      await db.reflectionDao.upsertReflection(
        reflectionDate: missedOn,
        reasonKeys: ['low_energy', 'too_busy'],
        missedHabitIds: [habitA],
      );

      final reasons = await db.reflectionDao.watchMostCommonReasons().first;

      expect(
        reasons.map((r) => r.reason),
        containsAll(<String>['low_energy', 'too_busy']),
      );
      expect(reasons.every((r) => r.count == 1), isTrue);
    });

    test('free-text reason is persisted rather than discarded', () async {
      await db.reflectionDao.upsertReflection(
        reflectionDate: missedOn,
        reasonKeys: ['low_energy'],
        customText: 'power cut all evening',
        followUpReasonKey: 'low_energy',
        followUpAnswer: 'early night',
        missedHabitIds: [habitA],
      );

      final row = await db.reflectionDao.getReflectionForDate(missedOn);

      expect(row?.customText, 'power cut all evening');
      expect(row?.followUpAnswer, 'early night');
      expect(row?.followUpReasonKey, 'low_energy');
    });

    test('upsert updates existing day instead of creating duplicate', () async {
      await db.reflectionDao.upsertReflection(
        reflectionDate: missedOn,
        reasonKeys: ['forgot'],
        missedHabitIds: [habitA],
      );
      await db.reflectionDao.upsertReflection(
        reflectionDate: missedOn,
        reasonKeys: ['forgot', 'traveling'],
        missedHabitIds: [habitA, habitB],
      );

      final rows = await db.select(db.habitReflections).get();
      expect(rows, hasLength(1));
      final keys = (jsonDecode(rows.single.reasonKeys) as List).cast<String>();
      expect(keys, containsAll(['forgot', 'traveling']));
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
