import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/category_dao.dart';
import 'daos/completion_dao.dart';
import 'daos/habit_dao.dart';
import 'daos/reflection_dao.dart';
import 'daos/task_dao.dart';
import 'tables/categories_table.dart';
import 'tables/daily_reflections_table.dart';
import 'tables/habit_completions_table.dart';
import 'tables/habit_reflections_table.dart';
import 'tables/habits_table.dart';
import 'tables/tasks_table.dart';

part 'app_database.g.dart';

/// The single Drift database for Tracely.
///
/// Offline-first: all data lives in a local SQLite file.
///
/// Schema history:
///   v1 — initial: Categories, Habits, HabitCompletions, DailyReflections
///   v2 — added HabitReflections (Pause & Reflect, §8.4a)
///   v3 — added Tasks (one-off to-dos, separate from recurring Habits)
///   v4 — migrated Health/Mind/Fitness/Learning's colorValue to Stitch's hues
@DriftDatabase(
  tables: [
    Categories,
    Habits,
    HabitCompletions,
    DailyReflections,
    HabitReflections,
    Tasks,
  ],
  daos: [CategoryDao, HabitDao, CompletionDao, ReflectionDao, TaskDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedDefaultCategories();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // v1 → v2: create the HabitReflections table
            await m.createTable(habitReflections);
          }
          if (from < 3) {
            // v2 → v3: create the Tasks table
            await m.createTable(tasks);
          }
          if (from < 4) {
            // v3 → v4: re-color the 4 built-in categories Stitch actually
            // specifies. Matched by name AND isBuiltIn so a user's own
            // category coincidentally named "Health" is never touched.
            await _recolorBuiltInCategories();
          }
        },
      );

  /// The Stitch-specified hues for the 4 built-in categories it defines.
  /// Shared by the v3→v4 migration and [_seedDefaultCategories] so a fresh
  /// install and an upgraded one end up with identical values.
  static const _stitchCategoryColors = {
    'Health': 0xFF5A7233,
    'Mind': 0xFF6B5B8C,
    'Fitness': 0xFFAC5E2D,
    'Learning': 0xFF3F6480,
  };

  Future<void> _recolorBuiltInCategories() async {
    for (final entry in _stitchCategoryColors.entries) {
      await (update(categories)
            ..where((c) =>
                c.name.equals(entry.key) & c.isBuiltIn.equals(true)))
          .write(CategoriesCompanion(colorValue: Value(entry.value)));
    }
  }

  // ---------------------------------------------------------------------------
  // Seeding
  // ---------------------------------------------------------------------------

  /// Seeds the 7 built-in categories on first app launch.
  ///
  /// Each category maps to an AppColors.category* constant (stored as int).
  /// The colorValue is the ARGB integer of the color. `emoji` holds an
  /// [AppIconRegistry] key, not a literal emoji character — see that
  /// registry's doc comment for why.
  Future<void> _seedDefaultCategories() async {
    final defaultCategories = [
      CategoriesCompanion.insert(
        name: 'Health',
        emoji: 'favorite',
        colorValue: _stitchCategoryColors['Health']!,
        sortOrder: const Value(0),
        isBuiltIn: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Mind',
        emoji: 'psychology',
        colorValue: _stitchCategoryColors['Mind']!,
        sortOrder: const Value(1),
        isBuiltIn: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Fitness',
        emoji: 'fitness_center',
        colorValue: _stitchCategoryColors['Fitness']!,
        sortOrder: const Value(2),
        isBuiltIn: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Learning',
        emoji: 'menu_book',
        colorValue: _stitchCategoryColors['Learning']!,
        sortOrder: const Value(3),
        isBuiltIn: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Creativity',
        emoji: 'palette',
        colorValue: 0xFFDB2777,
        sortOrder: const Value(4),
        isBuiltIn: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Social',
        emoji: 'groups',
        colorValue: 0xFF0891B2,
        sortOrder: const Value(5),
        isBuiltIn: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Self-Care',
        emoji: 'spa',
        colorValue: 0xFFD97706,
        sortOrder: const Value(6),
        isBuiltIn: const Value(true),
      ),
    ];

    for (final category in defaultCategories) {
      await into(categories).insert(category);
    }
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Permanently deletes one habit and every completion/reflection row
  /// that references it. Unlike [HabitDao.archiveHabit], this cannot be
  /// undone — the caller must confirm with the user first.
  Future<void> deleteHabit(int habitId) async {
    await transaction(() async {
      await (delete(habitCompletions)..where((c) => c.habitId.equals(habitId)))
          .go();
      await (delete(habitReflections)..where((r) => r.habitId.equals(habitId)))
          .go();
      await (delete(habits)..where((h) => h.id.equals(habitId))).go();
    });
  }

  /// Permanently deletes every habit, category, task, completion, and
  /// reflection, then reseeds the built-in categories — leaving the app
  /// as it was on first install. Used by Settings → Clear All Data.
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(habitCompletions).go();
      await delete(habitReflections).go();
      await delete(dailyReflections).go();
      await delete(tasks).go();
      await delete(habits).go();
      await delete(categories).go();
      await _seedDefaultCategories();
    });
  }
}

/// Opens the SQLite connection at the platform-appropriate path.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tracely.db'));
    return NativeDatabase.createInBackground(file);
  });
}
