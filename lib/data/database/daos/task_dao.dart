import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/tasks_table.dart';

part 'task_dao.g.dart';

/// Data Access Object for the Tasks table.
///
/// Kept deliberately simple — a flat CRUD surface. Filtering/grouping by
/// due date (overdue/today/tomorrow/upcoming) is domain logic and lives in
/// TaskRepository, not here.
@DriftAccessor(tables: [Tasks])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  /// Watch every task, most recently created first among ties, ordered
  /// primarily by due date (nulls last) so the repository can group cheaply.
  Stream<List<Task>> watchAllTasks() {
    return (select(tasks)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.dueDate,
                  mode: OrderingMode.asc,
                  nulls: NullsOrder.last,
                ),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Insert a new task. Returns the new row ID.
  Future<int> insertTask(TasksCompanion task) {
    return into(tasks).insert(task);
  }

  /// Toggle a task's done state.
  Future<void> setTaskDone(int id, bool isDone) async {
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(isDone: Value(isDone)),
    );
  }

  /// Permanently remove a task.
  Future<void> deleteTask(int id) async {
    await (delete(tasks)..where((t) => t.id.equals(id))).go();
  }
}
