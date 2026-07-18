import 'package:drift/drift.dart';

import 'habits_table.dart';

/// Drift table for habit completion records.
///
/// One row per habit per calendar day. The unique constraint enforces
/// this — toggling completion deletes/inserts, never duplicates.
class HabitCompletions extends Table {
  /// Auto-incrementing primary key.
  IntColumn get id => integer().autoIncrement()();

  /// The habit that was completed.
  IntColumn get habitId => integer().references(Habits, #id)();

  /// The calendar date this completion is for.
  /// Always normalized to midnight (00:00:00) local time.
  /// We store the day's intent, not the exact time.
  DateTimeColumn get completedDate => dateTime()();

  /// The actual timestamp when the user tapped complete.
  DateTimeColumn get completedAt => dateTime().withDefault(currentDateAndTime)();

  /// Whether this completion was on a streak-forgiveness recovery day.
  /// Recovery day = user missed the day but has their weekly grace credit.
  BoolColumn get isRecoveryDay => boolean().withDefault(const Constant(false))();

  /// Enforce one completion record per habit per calendar day.
  @override
  List<Set<Column>> get uniqueKeys => [
        {habitId, completedDate},
      ];
}
