import 'package:drift/drift.dart';

/// Drift table for habit categories.
///
/// Pre-seeded with 7 built-in categories on first launch.
/// Custom categories can be added by users (isBuiltIn = false).
/// Categories are soft-deleted via isArchived — never hard-deleted.
class Categories extends Table {
  /// Auto-incrementing primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Display name: "Health", "Mind", "Fitness", etc.
  TextColumn get name => text().withLength(min: 1, max: 50)();

  /// Emoji representing this category: "💪", "🧠", "📚", etc.
  TextColumn get emoji => text().withLength(min: 1, max: 10)();

  /// Color stored as integer ARGB value (e.g. 0xFF65A30D).
  /// Maps to one of AppColors.category* constants.
  IntColumn get colorValue => integer()();

  /// Display sort order within the category list.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Built-in categories cannot be deleted by the user.
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  /// Soft delete — archived categories are hidden from pickers.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// When this category was created.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
