import 'package:drift/drift.dart';

import 'categories_table.dart';

/// Drift table for user habits.
///
/// Habits are never hard-deleted — only archived (isArchived = true).
/// This preserves all historical completion data.
class Habits extends Table {
  /// Auto-incrementing primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Habit display name: "Morning Walk", "Read 20 pages", etc.
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Optional custom icon override — an [AppIconRegistry] key, not a
  /// literal emoji character. If null, the parent category's icon is used.
  /// Named `emoji` for historical/migration reasons.
  TextColumn get emoji => text().nullable().withLength(min: 1, max: 40)();

  /// Foreign key to the Categories table.
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// Frequency type:
  /// - 'daily'         → every calendar day
  /// - 'specific_days' → JSON list of weekday indices [1..7] (Mon=1, Sun=7)
  /// - 'x_per_week'    → JSON object {"times": N}
  TextColumn get frequencyType =>
      text().withDefault(const Constant('daily'))();

  /// Frequency configuration JSON.
  /// Null for 'daily', populated for 'specific_days' and 'x_per_week'.
  TextColumn get frequencyConfig => text().nullable()();

  /// Whether a reminder notification is enabled.
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Reminder time as "HH:mm" string (e.g. "08:30"). Null if no reminder.
  TextColumn get reminderTime => text().nullable()();

  /// Display sort order within the habits list.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Archived habits are hidden from daily view.
  /// Their completion history is fully preserved.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// When this habit was first created.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// When this habit was last modified.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
