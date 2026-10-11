import 'package:drift/drift.dart';

/// Drift table for missed-day reflections — ONE ROW PER DAY.
///
/// Stores what got in the way on a specific calendar day.
/// Enforces exactly one reflection row per day via a unique constraint on [reflectionDate].
/// Captures up to 2 reason keys, optional custom text, and follow-up answers.
class HabitReflections extends Table {
  /// Auto-incrementing primary key.
  IntColumn get id => integer().autoIncrement()();

  /// The day the habits were missed (midnight-normalized, local time).
  /// Unique constraint enforces exactly one reflection row per calendar day.
  DateTimeColumn get reflectionDate => dateTime().unique()();

  /// JSON list of up to 2 reason keys (e.g. '["low_energy", "too_busy"]').
  TextColumn get reasonKeys => text()();

  /// Custom free-text reason entered by the user in "My Reason".
  TextColumn get customText => text().nullable()();

  /// The reason key that triggered the follow-up question (if any).
  TextColumn get followUpReasonKey => text().nullable()();

  /// The user's answer to the follow-up question (if any).
  TextColumn get followUpAnswer => text().nullable()();

  /// JSON list of habit IDs missed on this day (e.g. '[1, 2]').
  TextColumn get missedHabitIds => text()();

  /// When this reflection was first created.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// When this reflection was last updated.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
