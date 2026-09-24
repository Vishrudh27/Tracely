/// Pure Dart data classes used as return types from TaskRepository.
///
/// Decouple the presentation layer from Drift-generated types, same
/// convention as habit_models.dart.
library;

/// 'low' | 'normal' | 'high', parsed from the Tasks.priority text column.
enum TaskPriority {
  low,
  normal,
  high;

  static TaskPriority fromStorage(String value) => switch (value) {
        'low' => TaskPriority.low,
        'high' => TaskPriority.high,
        _ => TaskPriority.normal,
      };

  String toStorage() => name;
}

/// Which group a task falls into for display — computed relative to
/// [today], never stored.
enum TaskGroup { overdue, today, tomorrow, upcoming }

/// A task bundled with its category display info (if any).
class TaskWithCategory {
  const TaskWithCategory({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.dueTime,
    required this.priority,
    required this.categoryName,
    required this.categoryEmoji,
    required this.categoryColorValue,
    required this.notes,
    required this.isDone,
  });

  final int id;
  final String title;

  /// Date-only (time component always midnight); null = no due date.
  final DateTime? dueDate;

  /// "HH:mm", e.g. "18:00". Null = no specific time.
  final String? dueTime;

  final TaskPriority priority;
  final String? categoryName;
  final String? categoryEmoji;
  final int? categoryColorValue;
  final String? notes;
  final bool isDone;

  /// Which bucket this task falls into "as of" [today]. Only meaningful
  /// for tasks that aren't done — callers filtering for the Done tab
  /// shouldn't consult this.
  TaskGroup groupFor(DateTime today) {
    if (dueDate == null) return TaskGroup.upcoming;
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final day0 = DateTime(today.year, today.month, today.day);
    final diff = due.difference(day0).inDays;
    if (diff < 0) return TaskGroup.overdue;
    if (diff == 0) return TaskGroup.today;
    if (diff == 1) return TaskGroup.tomorrow;
    return TaskGroup.upcoming;
  }
}
