import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories_table.dart';
import '../tables/habits_table.dart';

part 'habit_dao.g.dart';

/// Data Access Object for the Habits table.
///
/// Provides reactive streams (watch*) for the dashboard and habits list,
/// plus one-shot futures for CRUD operations.
@DriftAccessor(tables: [Habits, Categories])
class HabitDao extends DatabaseAccessor<AppDatabase> with _$HabitDaoMixin {
  HabitDao(super.db);

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Watch all active (non-archived) habits, ordered by sortOrder then createdAt.
  Stream<List<Habit>> watchActiveHabits() {
    return (select(habits)
          ..where((h) => h.isArchived.equals(false))
          ..orderBy([
            (h) => OrderingTerm.asc(h.sortOrder),
            (h) => OrderingTerm.asc(h.createdAt),
          ]))
        .watch();
  }

  /// Watch habits filtered by category.
  Stream<List<Habit>> watchHabitsByCategory(int categoryId) {
    return (select(habits)
          ..where(
            (h) =>
                h.isArchived.equals(false) & h.categoryId.equals(categoryId),
          )
          ..orderBy([(h) => OrderingTerm.asc(h.sortOrder)]))
        .watch();
  }

  /// Watch archived habits (for the Archived filter tab).
  Stream<List<Habit>> watchArchivedHabits() {
    return (select(habits)
          ..where((h) => h.isArchived.equals(true))
          ..orderBy([(h) => OrderingTerm.desc(h.updatedAt)]))
        .watch();
  }

  /// Get a single habit by ID.
  Future<Habit?> getHabitById(int id) {
    return (select(habits)..where((h) => h.id.equals(id))).getSingleOrNull();
  }

  /// Get all active habits as a one-shot future (for streak calculation).
  Future<List<Habit>> getActiveHabits() {
    return (select(habits)
          ..where((h) => h.isArchived.equals(false))
          ..orderBy([(h) => OrderingTerm.asc(h.sortOrder)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Insert a new habit. Returns the new row ID.
  Future<int> insertHabit(HabitsCompanion habit) {
    return into(habits).insert(habit);
  }

  /// Update an existing habit, writing only the fields present on [habit].
  ///
  /// `replace` rewrites the entire row, so any column the caller left absent
  /// falls back to its schema default — editing a habit's name that way also
  /// reset its sort order, cleared its reminder and moved its createdAt.
  Future<bool> updateHabit(HabitsCompanion habit) async {
    if (!habit.id.present) {
      throw ArgumentError('updateHabit requires habit.id to be set');
    }
    final rowsAffected =
        await (update(habits)..where((h) => h.id.equals(habit.id.value)))
            .write(habit);
    return rowsAffected > 0;
  }

  /// Archive a habit (soft delete — data preserved).
  Future<void> archiveHabit(int id) async {
    await (update(habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Restore an archived habit.
  Future<void> restoreHabit(int id) async {
    await (update(habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        isArchived: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update the sort orders of multiple habits atomically.
  /// [orderedIds] should be the full ordered list of active habit IDs.
  Future<void> reorderHabits(List<int> orderedIds) async {
    await db.transaction(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        await (update(habits)..where((h) => h.id.equals(orderedIds[i]))).write(
          HabitsCompanion(sortOrder: Value(i)),
        );
      }
    });
  }

  /// Count active habits.
  Future<int> countActiveHabits() async {
    final count = countAll(filter: habits.isArchived.equals(false));
    final query = selectOnly(habits)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
