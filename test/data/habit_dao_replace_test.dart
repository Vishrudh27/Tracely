import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('updateHabit with a partial companion preserves untouched columns',
      () async {
    final categoryId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: 'Health',
            emoji: '💚',
            colorValue: 0xFF65A30D,
          ),
        );

    final habitId = await db.habitDao.insertHabit(
      HabitsCompanion.insert(
        name: 'Walk',
        categoryId: categoryId,
        emoji: const Value('🚶'),
        sortOrder: const Value(7),
        reminderEnabled: const Value(true),
        reminderTime: const Value('08:30'),
        frequencyType: const Value('specific_days'),
        frequencyConfig: const Value('[1,3,5]'),
      ),
    );

    await db.habitDao.updateHabit(
      HabitsCompanion(
        id: Value(habitId),
        name: const Value('Walk further'),
        categoryId: Value(categoryId),
        updatedAt: Value(DateTime.now()),
      ),
    );

    final after = await db.habitDao.getHabitById(habitId);

    expect(after!.name, 'Walk further');
    expect(after.sortOrder, 7, reason: 'sortOrder must survive a partial edit');
    expect(after.reminderEnabled, true,
        reason: 'reminderEnabled must survive a partial edit');
    expect(after.reminderTime, '08:30',
        reason: 'reminderTime must survive a partial edit');
    expect(after.emoji, '🚶', reason: 'emoji must survive a partial edit');
  });
}
