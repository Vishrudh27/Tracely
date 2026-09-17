import 'package:drift/drift.dart';

import 'habits_table.dart';

/// Drift table for habit-level missed-day reflections.
///
/// Stores why a user missed a specific habit on a specific day.
/// Intentionally separate from DailyReflections (morning mood) to
/// keep the two distinct user experiences non-conflated.
///
/// Used by PauseAndReflectSheet (§4.5) to persist reflection reasons,
/// and by MostCommonReasonsCard (Phase 3) to surface patterns.
class HabitReflections extends Table {
  /// Auto-incrementing primary key.
  IntColumn get id => integer().autoIncrement()();

  /// The habit that was missed.
  IntColumn get habitId =>
      integer().references(Habits, #id)();

  /// The date the habit was missed (midnight-normalized, local time).
  DateTimeColumn get missedDate => dateTime()();

  /// The selected reason from the taxonomy.
  ///
  /// One of: 'energy', 'time', 'forgot', 'motivation',
  ///         'environment', 'other'
  TextColumn get reason => text()();

  /// Optional follow-up answer for the reason-specific question.
  /// Nullable — not all reason categories have a follow-up question.
  TextColumn get followUpAnswer => text().nullable()();

  /// When this reflection was created.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
