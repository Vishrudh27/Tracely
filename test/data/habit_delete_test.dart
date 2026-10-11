import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('deleteHabit removes the habit and its completions/reflections',
      () async {
    final categoryId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: 'Health',
            emoji: '💚',
            colorValue: 0xFF65A30D,
          ),
        );

    final keptHabitId = await db.habitDao.insertHabit(
      HabitsCompanion.insert(name: 'Stretch', categoryId: categoryId),
    );
    final deletedHabitId = await db.habitDao.insertHabit(
      HabitsCompanion.insert(name: 'Walk', categoryId: categoryId),
    );

    final today = DateTime.now();
    for (final habitId in [keptHabitId, deletedHabitId]) {
      await db.into(db.habitCompletions).insert(
            HabitCompletionsCompanion.insert(
              habitId: habitId,
              completedDate: today,
            ),
          );
    }
    await db.reflectionDao.upsertReflection(
      reflectionDate: today,
      reasonKeys: ['too_busy'],
      missedHabitIds: [keptHabitId, deletedHabitId],
    );

    await db.deleteHabit(deletedHabitId);

    final remainingHabit = await db.habitDao.getHabitById(deletedHabitId);
    expect(remainingHabit, isNull);

    final deletedHabitCompletions = await (db.select(db.habitCompletions)
          ..where((c) => c.habitId.equals(deletedHabitId)))
        .get();
    expect(deletedHabitCompletions, isEmpty);

    // The reflection on today should no longer reference deletedHabitId
    final reflectedHabits =
        await db.reflectionDao.getReflectedHabitIds(today);
    expect(reflectedHabits, isNot(contains(deletedHabitId)));
    expect(reflectedHabits, contains(keptHabitId));

    // The other habit and its completions must survive
    final keptHabit = await db.habitDao.getHabitById(keptHabitId);
    expect(keptHabit, isNotNull);

    final keptHabitCompletions = await (db.select(db.habitCompletions)
          ..where((c) => c.habitId.equals(keptHabitId)))
        .get();
    expect(keptHabitCompletions, hasLength(1));
  });
}
