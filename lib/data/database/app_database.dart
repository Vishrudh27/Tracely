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
  int get schemaVersion => 5;

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
          if (from < 5) {
            // v4 → v5: `emoji` used to hold a literal emoji character; it
            // now holds an AppIconRegistry key (see _seedDefaultCategories),
            // but nothing ever rewrote existing rows, so upgraded installs
            // still had the old character and every built-in category's
            // icon silently fell back to AppIconRegistry.fallback (a star).
            await _backfillBuiltInCategoryIconKeys();
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

  /// The 7 built-ins' current [AppIconRegistry] keys — same names/keys as
  /// [_seedDefaultCategories], kept separate so that method still reads as
  /// the single source of truth for a *fresh* install.
  static const _builtInCategoryIconKeys = {
    'Health': 'favorite',
    'Mind': 'psychology',
    'Fitness': 'fitness_center',
    'Learning': 'menu_book',
    'Creativity': 'palette',
    'Social': 'groups',
    'Self-Care': 'spa',
  };

  Future<void> _backfillBuiltInCategoryIconKeys() async {
    for (final entry in _builtInCategoryIconKeys.entries) {
      await (update(categories)
            ..where((c) =>
                c.name.equals(entry.key) & c.isBuiltIn.equals(true)))
          .write(CategoriesCompanion(emoji: Value(entry.value)));
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

  // ---------------------------------------------------------------------------
  // Export / import (Settings → Your Data)
  // ---------------------------------------------------------------------------

  /// The marker `importData` checks for before touching the database, so an
  /// unrelated JSON file gets rejected instead of half-imported.
  static const backupAppMarker = 'tracely';

  /// Every row in the database, keyed by table name. Each row is whatever
  /// its drift-generated `toJson()` produces — nothing here interprets
  /// column values by hand, so it round-trips through [importData] exactly.
  Future<Map<String, dynamic>> exportData() async {
    return {
      'app': backupAppMarker,
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': {
        'categories':
            (await select(categories).get()).map((r) => r.toJson()).toList(),
        'habits':
            (await select(habits).get()).map((r) => r.toJson()).toList(),
        'habitCompletions': (await select(habitCompletions).get())
            .map((r) => r.toJson())
            .toList(),
        'habitReflections': (await select(habitReflections).get())
            .map((r) => r.toJson())
            .toList(),
        'dailyReflections': (await select(dailyReflections).get())
            .map((r) => r.toJson())
            .toList(),
        'tasks': (await select(tasks).get()).map((r) => r.toJson()).toList(),
      },
    };
  }

  /// Replaces everything in the database with a prior [exportData] result.
  /// Runs as one transaction so a bad backup can't half-apply. The caller
  /// must already have confirmed with the user and checked
  /// `data['app'] == backupAppMarker` — this only writes rows.
  ///
  /// Unlike [clearAllData], this does NOT reseed the built-in categories —
  /// the backup's own categories (including built-ins, by their original
  /// ids) replace them, so habits and tasks that reference those ids still
  /// resolve.
  Future<void> importData(Map<String, dynamic> data) async {
    final tablesJson = data['tables'] as Map<String, dynamic>;
    List<Map<String, dynamic>> rowsOf(String key) =>
        (tablesJson[key] as List? ?? const [])
            .cast<Map<String, dynamic>>();

    await transaction(() async {
      await delete(habitCompletions).go();
      await delete(habitReflections).go();
      await delete(dailyReflections).go();
      await delete(tasks).go();
      await delete(habits).go();
      await delete(categories).go();

      // Parents before children, so foreign keys resolve as each row lands.
      for (final row in rowsOf('categories')) {
        await into(categories).insert(
          Category.fromJson(row),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final row in rowsOf('habits')) {
        await into(habits).insert(
          Habit.fromJson(row),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final row in rowsOf('habitCompletions')) {
        await into(habitCompletions).insert(
          HabitCompletion.fromJson(row),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final row in rowsOf('habitReflections')) {
        await into(habitReflections).insert(
          HabitReflection.fromJson(row),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final row in rowsOf('dailyReflections')) {
        await into(dailyReflections).insert(
          DailyReflection.fromJson(row),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final row in rowsOf('tasks')) {
        await into(tasks).insert(
          Task.fromJson(row),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Habit completions as CSV, joined with the habit name — the one sheet
  /// most likely to be useful opened outside the app. The full backup for
  /// round-tripping is [exportData]/JSON, not this.
  Future<String> exportCompletionsCsv() async {
    final query = select(habitCompletions).join([
      innerJoin(habits, habits.id.equalsExp(habitCompletions.habitId)),
    ])
      ..orderBy([OrderingTerm.asc(habitCompletions.completedDate)]);
    final rows = await query.get();

    final buffer = StringBuffer('Date,Habit,Completed At,Recovery Day\n');
    for (final row in rows) {
      final completion = row.readTable(habitCompletions);
      final habit = row.readTable(habits);
      buffer.writeln([
        completion.completedDate.toIso8601String().split('T').first,
        _csvField(habit.name),
        completion.completedAt.toIso8601String(),
        completion.isRecoveryDay,
      ].join(','));
    }
    return buffer.toString();
  }

  static String _csvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
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
