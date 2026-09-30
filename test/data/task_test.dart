import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/models/task_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskDao', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async => db.close());

    test('inserted task is emitted by watchAllTasks', () async {
      final emissions = <List<Task>>[];
      final sub = db.taskDao.watchAllTasks().listen(emissions.add);
      await pumpEventQueue();

      await db.taskDao.insertTask(
        TasksCompanion.insert(title: 'Finish the assignment'),
      );
      await pumpEventQueue();

      expect(emissions.last, hasLength(1));
      expect(emissions.last.single.title, 'Finish the assignment');
      expect(emissions.last.single.isDone, isFalse);
      await sub.cancel();
    });

    test('setTaskDone toggles only isDone, nothing else', () async {
      final id = await db.taskDao.insertTask(
        TasksCompanion.insert(title: 'Read'),
      );

      await db.taskDao.setTaskDone(id, true);
      final tasks = await db.select(db.tasks).get();

      expect(tasks.single.isDone, isTrue);
      expect(tasks.single.title, 'Read');
    });

    test('deleteTask removes the row', () async {
      final id = await db.taskDao.insertTask(
        TasksCompanion.insert(title: 'Temporary'),
      );

      await db.taskDao.deleteTask(id);
      final tasks = await db.select(db.tasks).get();

      expect(tasks, isEmpty);
    });
  });

  group('TaskWithCategory.groupFor', () {
    final today = DateTime(2026, 9, 19);

    TaskWithCategory taskDue(DateTime? due) => TaskWithCategory(
          id: 1,
          title: 'x',
          dueDate: due,
          dueTime: null,
          priority: TaskPriority.normal,
          categoryName: null,
          categoryEmoji: null,
          categoryColorValue: null,
          notes: null,
          isDone: false,
        );

    test('a date before today is overdue', () {
      expect(
        taskDue(DateTime(2026, 9, 18)).groupFor(today),
        TaskGroup.overdue,
      );
    });

    test('today\'s date is today, not overdue', () {
      expect(taskDue(DateTime(2026, 9, 19)).groupFor(today), TaskGroup.today);
    });

    test('the next calendar day is tomorrow', () {
      expect(
        taskDue(DateTime(2026, 9, 20)).groupFor(today),
        TaskGroup.tomorrow,
      );
    });

    test('two days out is upcoming, not tomorrow', () {
      expect(
        taskDue(DateTime(2026, 9, 21)).groupFor(today),
        TaskGroup.upcoming,
      );
    });

    test('no due date is upcoming', () {
      expect(taskDue(null).groupFor(today), TaskGroup.upcoming);
    });
  });
}
