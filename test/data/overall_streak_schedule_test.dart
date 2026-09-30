import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/extensions/date_extensions.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/repositories/habit_repository.dart';

/// Regression test for the overall streak's schedule-awareness: a rest day
/// for every active habit should not break [HabitRepository.watchOverallStreak],
/// same fix as the single-habit case in habit_schedule_test.dart.
void main() {
  late AppDatabase db;
  late HabitRepository repo;

  Future<int> insertMonToFriHabit() async {
    final categoryId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: 'Health',
            emoji: 'favorite',
            colorValue: 0xFF000000,
          ),
        );
    return db.habitDao.insertHabit(
      HabitsCompanion.insert(
        name: 'Morning walk',
        categoryId: categoryId,
        frequencyType: const Value('specific_days'),
        frequencyConfig: const Value('[1,2,3,4,5]'), // Mon–Fri
      ),
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HabitRepository(db.habitDao, db.completionDao, db.categoryDao);
  });

  tearDown(() async => db.close());

  test('a Mon–Fri-only account keeps a 14-day streak across both weekends '
      'in it', () async {
    final habitId = await insertMonToFriHabit();

    // 14 consecutive calendar days always contain exactly 10 weekdays,
    // whatever day of the week "today" happens to be — two full weeks, one
    // Mon–Fri run in each. Complete every one of them. If the two weekends
    // inside this window wrongly broke the streak (the bug this test
    // guards), currentStreak would come out far short of 10 on every day of
    // the week except when today itself is a Friday.
    final today = DateTime.now().startOfDay;
    for (var i = 0; i < 14; i++) {
      final day = today.addDays(-i);
      if (day.weekday <= 5) {
        await db.completionDao.toggleCompletion(habitId, day);
      }
    }

    final streak = await repo.watchOverallStreak(today).first;
    expect(streak.currentStreak, 10);
  });

  test('a genuinely missed scheduled weekday still breaks the streak',
      () async {
    final habitId = await insertMonToFriHabit();

    // Fixed historical dates (verified Mon/Tue/Wed/Thu), so this doesn't
    // depend on "today" at all — checked via longestStreak instead of
    // currentStreak for that reason.
    final mon = DateTime(2026, 1, 5);
    final tue = DateTime(2026, 1, 6);
    // Wed 2026-01-07 deliberately skipped — a real miss of a scheduled day.
    final thu = DateTime(2026, 1, 8);

    await db.completionDao.toggleCompletion(habitId, mon);
    await db.completionDao.toggleCompletion(habitId, tue);
    await db.completionDao.toggleCompletion(habitId, thu);

    final streak = await repo.watchOverallStreak(DateTime.now()).first;
    expect(streak.longestStreak, 2); // Mon–Tue; Thu starts over alone
  });

  test('with no active habits, every day counts (no stale infinite streak)',
      () async {
    final streak = await repo.watchOverallStreak(DateTime.now()).first;
    expect(streak.currentStreak, 0);
  });
}
