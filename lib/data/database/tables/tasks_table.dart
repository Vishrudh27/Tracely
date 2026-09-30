import 'package:drift/drift.dart';

import 'categories_table.dart';

/// Drift table for one-off to-do tasks.
///
/// Lighter-weight than Habits — no frequency, no streak. Tasks ARE
/// hard-deleted (unlike Habits/Categories) since no historical analytics
/// are attached to them once they're gone.
class Tasks extends Table {
  /// Auto-incrementing primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Task title: "Finish the assignment", etc.
  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// Due date, date-only (time-of-day lives in [dueTime]). Null means no
  /// due date was set — such tasks sort under "Upcoming".
  DateTimeColumn get dueDate => dateTime().nullable()();

  /// Due time as "HH:mm" (e.g. "18:00"). Null means no specific time.
  TextColumn get dueTime => text().nullable()();

  /// 'low' | 'normal' | 'high'.
  TextColumn get priority => text().withDefault(const Constant('normal'))();

  /// Optional foreign key to Categories — tasks reuse the same categories
  /// as Habits rather than a separate task-category system.
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  /// Optional free-text notes.
  TextColumn get notes => text().nullable()();

  /// Whether the task has been completed.
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();

  /// When this task was created.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
