import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/daos/category_dao.dart';
import '../database/daos/task_dao.dart';
import '../models/task_models.dart';
import '../services/database_service.dart';

/// Repository providing all task-related data to the presentation layer.
///
/// Combines TaskDao + CategoryDao to produce TaskWithCategory domain
/// objects, the same pattern HabitRepository uses for habits.
class TaskRepository {
  const TaskRepository(this._taskDao, this._categoryDao);

  final TaskDao _taskDao;
  final CategoryDao _categoryDao;

  /// Watch every task (done and not) with its category resolved.
  ///
  /// Grouping by due date (overdue/today/tomorrow/upcoming) depends on
  /// "today", which changes without any row changing, so it's the
  /// caller's job via [TaskWithCategory.groupFor] rather than baked in here.
  Stream<List<TaskWithCategory>> watchTasks() {
    final controller = StreamController<List<TaskWithCategory>>();
    List<Task>? latestTasks;
    List<Category>? latestCategories;

    void emit() {
      final tasks = latestTasks;
      final cats = latestCategories;
      if (tasks == null || cats == null) return;
      final categoriesById = {for (final c in cats) c.id: c};
      controller.add([
        for (final task in tasks)
          TaskWithCategory(
            id: task.id,
            title: task.title,
            dueDate: task.dueDate,
            dueTime: task.dueTime,
            priority: TaskPriority.fromStorage(task.priority),
            categoryName: categoriesById[task.categoryId]?.name,
            categoryEmoji: categoriesById[task.categoryId]?.emoji,
            categoryColorValue: categoriesById[task.categoryId]?.colorValue,
            notes: task.notes,
            isDone: task.isDone,
          ),
      ]);
    }

    final taskSub = _taskDao.watchAllTasks().listen((tasks) {
      latestTasks = tasks;
      emit();
    });
    final categorySub = _categoryDao.watchActiveCategories().listen((cats) {
      latestCategories = cats;
      emit();
    });

    controller.onCancel = () {
      taskSub.cancel();
      categorySub.cancel();
    };

    return controller.stream;
  }

  Future<int> addTask({
    required String title,
    DateTime? dueDate,
    String? dueTime,
    TaskPriority priority = TaskPriority.normal,
    int? categoryId,
    String? notes,
  }) {
    return _taskDao.insertTask(
      TasksCompanion.insert(
        title: title,
        dueDate: Value(dueDate),
        dueTime: Value(dueTime),
        priority: Value(priority.toStorage()),
        categoryId: Value(categoryId),
        notes: Value(notes),
      ),
    );
  }

  Future<void> setTaskDone(int id, bool isDone) =>
      _taskDao.setTaskDone(id, isDone);

  Future<void> deleteTask(int id) => _taskDao.deleteTask(id);
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TaskRepository(db.taskDao, db.categoryDao);
});

final tasksProvider = StreamProvider<List<TaskWithCategory>>((ref) {
  return ref.watch(taskRepositoryProvider).watchTasks();
});

/// Which filter chip is selected on the Tasks screen.
enum TaskFilter { today, upcoming, overdue, done }

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.today;

  void select(TaskFilter filter) => state = filter;
}

final taskFilterProvider =
    NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);
