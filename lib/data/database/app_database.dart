import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/category_dao.dart';
import 'daos/completion_dao.dart';
import 'daos/habit_dao.dart';
import 'daos/reflection_dao.dart';
import 'tables/categories_table.dart';
import 'tables/daily_reflections_table.dart';
import 'tables/habit_completions_table.dart';
import 'tables/habits_table.dart';

part 'app_database.g.dart';

/// The single Drift database for Tracely.
///
/// Offline-first: all data lives in a local SQLite file.
/// Schema version starts at 1. Migrations added as schema evolves.
@DriftDatabase(
  tables: [Categories, Habits, HabitCompletions, DailyReflections],
  daos: [CategoryDao, HabitDao, CompletionDao, ReflectionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedDefaultCategories();
        },
      );

  // ---------------------------------------------------------------------------
  // Seeding
  // ---------------------------------------------------------------------------

  /// Seeds the 7 built-in categories on first app launch.
  ///
  /// Each category maps to an AppColors.category* constant (stored as int).
  /// The colorValue is the ARGB integer of the color.
  Future<void> _seedDefaultCategories() async {
    final defaultCategories = [
      CategoriesCompanion.insert(
        name: 'Health',
        emoji: '💚',
        colorValue: 0xFF65A30D,
        sortOrder: const Value(0),
        isBuiltIn: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Mind',
        emoji: '🧠',
        colorValue: 0xFF7C3AED,
        sortOrder: const Value(1),
        isBuiltIn: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Fitness',
        emoji: '💪',
        colorValue: 0xFFEA580C,
        sortOrder: const Value(2),
        isBuiltIn: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Learning',
        emoji: '📚',
        colorValue: 0xFF2563EB,
        sortOrder: const Value(3),
        isBuiltIn: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Creativity',
        emoji: '🎨',
        colorValue: 0xFFDB2777,
        sortOrder: const Value(4),
        isBuiltIn: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Social',
        emoji: '🤝',
        colorValue: 0xFF0891B2,
        sortOrder: const Value(5),
        isBuiltIn: const Value(true),
      ),
      CategoriesCompanion.insert(
        name: 'Self-Care',
        emoji: '🧘',
        colorValue: 0xFFD97706,
        sortOrder: const Value(6),
        isBuiltIn: const Value(true),
      ),
    ];

    for (final category in defaultCategories) {
      await into(categories).insert(category);
    }
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
