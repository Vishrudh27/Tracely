import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('exportData → importData round-trips ids and row counts', () async {
    // `db` already has the 7 built-in categories from onCreate seeding —
    // this adds one more custom one on top.
    final categoryId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: 'Custom',
            emoji: 'favorite',
            colorValue: 0xFF65A30D,
          ),
        );
    final habitId = await db.habitDao.insertHabit(
      HabitsCompanion.insert(name: 'Stretch', categoryId: categoryId),
    );
    await db.into(db.habitCompletions).insert(
          HabitCompletionsCompanion.insert(
            habitId: habitId,
            completedDate: DateTime(2026, 9, 1),
          ),
        );
    await db.into(db.tasks).insert(
          TasksCompanion.insert(title: 'Finish the report'),
        );

    final backup = await db.exportData();
    expect(backup['app'], AppDatabase.backupAppMarker);

    // Import into a second, freshly-seeded database, the way "Import from
    // backup" would after clearing the current one's data.
    final restored = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(restored.close);
    await restored.importData(backup);

    // 7 built-ins (re-created by the source db's own onCreate seeding, then
    // carried over by the backup) plus the 1 custom category — not
    // re-seeded again on top by the restore.
    final categories = await restored.select(restored.categories).get();
    expect(categories, hasLength(8));
    final restoredCustom =
        categories.singleWhere((c) => c.id == categoryId);
    expect(restoredCustom.name, 'Custom');

    final habits = await restored.select(restored.habits).get();
    expect(habits, hasLength(1));
    expect(habits.single.id, habitId);
    expect(habits.single.categoryId, categoryId);

    final completions = await restored.select(restored.habitCompletions).get();
    expect(completions, hasLength(1));
    expect(completions.single.habitId, habitId);

    final tasks = await restored.select(restored.tasks).get();
    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'Finish the report');
  });

  test('importData replaces existing data rather than merging', () async {
    final oldCategoryId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: 'Old',
            emoji: 'favorite',
            colorValue: 0xFF000000,
          ),
        );
    await db.habitDao.insertHabit(
      HabitsCompanion.insert(name: 'Old habit', categoryId: oldCategoryId),
    );

    final backup = {
      'app': AppDatabase.backupAppMarker,
      'schemaVersion': 4,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': {
        'categories': [
          {
            'id': 99,
            'name': 'New',
            'emoji': 'favorite',
            'colorValue': 0xFFFFFFFF,
            'sortOrder': 0,
            'isBuiltIn': false,
            'isArchived': false,
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
        'habits': [],
        'habitCompletions': [],
        'habitReflections': [],
        'dailyReflections': [],
        'tasks': [],
      },
    };

    await db.importData(backup);

    final categories = await db.select(db.categories).get();
    expect(categories, hasLength(1));
    expect(categories.single.name, 'New');

    final habits = await db.select(db.habits).get();
    expect(habits, isEmpty);
  });
}
