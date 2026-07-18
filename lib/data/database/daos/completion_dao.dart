import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/habit_completions_table.dart';
import '../tables/habits_table.dart';

part 'completion_dao.g.dart';

/// Data Access Object for the HabitCompletions table.
///
/// Provides reactive streams for dashboard data and one-shot
/// methods for toggling completion state.
@DriftAccessor(tables: [HabitCompletions, Habits])
class CompletionDao extends DatabaseAccessor<AppDatabase>
    with _$CompletionDaoMixin {
  CompletionDao(super.db);

  // ---------------------------------------------------------------------------
  // Toggle completion
  // ---------------------------------------------------------------------------

  /// Toggle the completion state for a habit on a specific date.
  ///
  /// If the habit is already completed on [date], the record is deleted.
  /// If not, a new completion record is inserted.
  /// [date] should be midnight-normalized (use DateTime.startOfDay).
  Future<void> toggleCompletion(int habitId, DateTime date) async {
    final existing = await (select(habitCompletions)
          ..where(
            (c) => c.habitId.equals(habitId) & c.completedDate.equals(date),
          ))
        .getSingleOrNull();

    if (existing != null) {
      await (delete(habitCompletions)..where((c) => c.id.equals(existing.id)))
          .go();
    } else {
      await into(habitCompletions).insert(
        HabitCompletionsCompanion.insert(
          habitId: habitId,
          completedDate: date,
        ),
      );
    }
  }

  /// Check if a habit is completed on a given date.
  Future<bool> isCompleted(int habitId, DateTime date) async {
    final result = await (select(habitCompletions)
          ..where(
            (c) => c.habitId.equals(habitId) & c.completedDate.equals(date),
          ))
        .getSingleOrNull();
    return result != null;
  }

  // ---------------------------------------------------------------------------
  // Dashboard streams
  // ---------------------------------------------------------------------------

  /// Watch all completions for a specific date (for dashboard reactive update).
  Stream<List<HabitCompletion>> watchCompletionsForDate(DateTime date) {
    return (select(habitCompletions)
          ..where((c) => c.completedDate.equals(date)))
        .watch();
  }

  /// Watch completion records for the current week (7 days from [weekStart]).
  Stream<List<HabitCompletion>> watchWeekCompletions(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return (select(habitCompletions)
          ..where(
            (c) =>
                c.completedDate.isBiggerOrEqualValue(weekStart) &
                c.completedDate.isSmallerOrEqualValue(weekEnd),
          ))
        .watch();
  }

  /// Watch recent completions across all habits, newest first.
  Stream<List<HabitCompletion>> watchRecentCompletions({int limit = 5}) {
    return (select(habitCompletions)
          ..orderBy([(c) => OrderingTerm.desc(c.completedAt)])
          ..limit(limit))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // Statistics reads
  // ---------------------------------------------------------------------------

  /// Get all completions for a habit since [since] date (for streak calc).
  Future<List<HabitCompletion>> getCompletionsForHabit(
    int habitId, {
    DateTime? since,
  }) async {
    final query = select(habitCompletions)
      ..where((c) => c.habitId.equals(habitId));
    if (since != null) {
      query.where((c) => c.completedDate.isBiggerOrEqualValue(since));
    }
    query.orderBy([(c) => OrderingTerm.asc(c.completedDate)]);
    return query.get();
  }

  /// Get all completions since [since] date across all habits.
  Future<List<HabitCompletion>> getAllCompletionsSince(DateTime since) {
    return (select(habitCompletions)
          ..where((c) => c.completedDate.isBiggerOrEqualValue(since))
          ..orderBy([(c) => OrderingTerm.asc(c.completedDate)]))
        .get();
  }

  /// Get completions for a date range (for heatmap rendering).
  Future<List<HabitCompletion>> getCompletionsInRange(
    DateTime start,
    DateTime end,
  ) {
    return (select(habitCompletions)
          ..where(
            (c) =>
                c.completedDate.isBiggerOrEqualValue(start) &
                c.completedDate.isSmallerOrEqualValue(end),
          ))
        .get();
  }
}
