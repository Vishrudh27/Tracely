import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/repositories/habit_repository.dart';

/// Regression tests for the midnight-rollover bug.
///
/// The repository used to read `DateTime.now()` when a stream was created and
/// hold that day for the stream's lifetime. Left open past midnight, the
/// dashboard kept filtering yesterday while writes landed on today, so ticking
/// a habit appeared to do nothing. These tests pin the behaviour that the day
/// is whatever the caller passes in.
void main() {
  late AppDatabase db;
  late HabitRepository repo;
  late int habitId;

  final today = DateTime(2026, 9, 17);
  final yesterday = DateTime(2026, 9, 16);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HabitRepository(db.habitDao, db.completionDao, db.categoryDao);

    final categoryId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: 'Health',
            emoji: '💚',
            colorValue: 0xFF65A30D,
          ),
        );
    habitId = await db.habitDao.insertHabit(
      HabitsCompanion.insert(name: 'Walk', categoryId: categoryId),
    );
  });

  tearDown(() async => db.close());

  test('watchTodaysHabits reports completion against the day it was given',
      () async {
    await repo.toggleCompletion(habitId, yesterday);

    final asOfYesterday = await repo.watchTodaysHabits(yesterday).first;
    final asOfToday = await repo.watchTodaysHabits(today).first;

    expect(asOfYesterday.single.isCompletedToday, isTrue);
    expect(
      asOfToday.single.isCompletedToday,
      isFalse,
      reason: 'a completion on the 16th must not count on the 17th',
    );
  });

  test('toggleCompletion writes to the day the caller is displaying', () async {
    await repo.toggleCompletion(habitId, today);

    final completions = await db.completionDao.getCompletionsInRange(
      today,
      today,
    );

    expect(completions, hasLength(1));
    expect(completions.single.completedDate, today);
  });

  test('progress denominator follows the supplied day', () async {
    await repo.toggleCompletion(habitId, today);

    final progressToday = await repo.watchTodaysProgress(today).first;
    final progressYesterday = await repo.watchTodaysProgress(yesterday).first;

    expect(progressToday.completedCount, 1);
    expect(progressToday.totalCount, 1);
    expect(progressYesterday.completedCount, 0);
    expect(progressYesterday.totalCount, 1);
  });

  test('habit breakdowns re-emit when a completion is toggled', () async {
    final emissions = <int>[];
    final refreshed = Completer<int>();

    final sub = repo.watchHabitBreakdowns(today).listen((rows) {
      final total = rows.single.totalCompletions;
      emissions.add(total);
      if (total == 1 && !refreshed.isCompleted) refreshed.complete(total);
    });

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await repo.toggleCompletion(habitId, today);

    final total = await refreshed.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw StateError(
        'breakdown never refreshed after a completion; saw $emissions',
      ),
    );
    await sub.cancel();

    expect(total, 1);
  });
}
