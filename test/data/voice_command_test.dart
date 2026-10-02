import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/repositories/habit_repository.dart';
import 'package:habit_tracker/data/repositories/task_repository.dart';

/// The repository writes a voice command ends in. Reminder scheduling hits
/// the notifications plugin, which isn't available here — ReminderService
/// swallows that, which is also what keeps these saves from failing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late HabitRepository habits;
  late TaskRepository tasks;
  late int categoryId;
  final today = DateTime(2026, 9, 23);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    habits = HabitRepository(db.habitDao, db.completionDao, db.categoryDao);
    tasks = TaskRepository(db.taskDao, db.categoryDao);
    categoryId = (await db.select(db.categories).get()).first.id;
  });

  tearDown(() async => db.close());

  Future<int> addHabit(String name) => habits.createHabit(
        HabitsCompanion.insert(name: name, categoryId: categoryId),
      );

  group('setCompleted', () {
    test('twice still leaves exactly one completion', () async {
      final id = await addHabit('Meditate');
      await habits.setCompleted(id, today);
      await habits.setCompleted(id, today);
      final rows = await db.select(db.habitCompletions).get();
      expect(rows, hasLength(1));
      expect(await db.completionDao.isCompleted(id, today), isTrue);
    });

    test('never un-does a habit already ticked by the toggle', () async {
      final id = await addHabit('Meditate');
      await habits.toggleCompletion(id, today);
      await habits.setCompleted(id, today);
      expect(await db.completionDao.isCompleted(id, today), isTrue);
    });
  });

  test('createHabit round-trips schedule and reminder', () async {
    final id = await habits.createHabit(
      HabitsCompanion.insert(
        name: 'Meditate',
        categoryId: categoryId,
        frequencyType: const Value('specific_days'),
        frequencyConfig: const Value('[1,3]'),
        reminderEnabled: const Value(true),
        reminderTime: const Value('19:00'),
      ),
    );
    final h = (await db.habitDao.getHabitById(id))!;
    expect(h.frequencyType, 'specific_days');
    expect(h.frequencyConfig, '[1,3]');
    expect(h.reminderEnabled, isTrue);
    expect(h.reminderTime, '19:00');
  });

  test('updateHabit can clear a reminder', () async {
    final id = await habits.createHabit(
      HabitsCompanion.insert(
        name: 'Run',
        categoryId: categoryId,
        reminderEnabled: const Value(true),
        reminderTime: const Value('06:00'),
      ),
    );
    await habits.updateHabit(
      HabitsCompanion(
        id: Value(id),
        reminderEnabled: const Value(false),
        reminderTime: const Value(null),
      ),
    );
    final h = (await db.habitDao.getHabitById(id))!;
    expect(h.reminderEnabled, isFalse);
    expect(h.reminderTime, isNull);
    expect(h.name, 'Run');
  });

  group('tasks', () {
    test('addTask stores a midnight date and HH:mm time', () async {
      final id = await tasks.addTask(
        title: 'Call mom',
        dueDate: DateTime(2026, 9, 24),
        dueTime: '18:30',
      );
      final t = (await db.taskDao.getTaskById(id))!;
      expect(t.dueDate, DateTime(2026, 9, 24));
      expect(t.dueTime, '18:30');
    });

    test('setTaskDone and deleteTask', () async {
      final id = await tasks.addTask(title: 'Study');
      await tasks.setTaskDone(id, true);
      expect((await db.taskDao.getTaskById(id))!.isDone, isTrue);
      await tasks.deleteTask(id);
      expect(await db.taskDao.getTaskById(id), isNull);
    });
  });

  test('a habit with a recorded reason is not "missed" again', () async {
    final yesterday = today.subtract(const Duration(days: 1));
    final a = await addHabit('Workout');
    final b = await addHabit('Read');
    await db.reflectionDao.createHabitReflection(
      habitId: a,
      missedDate: yesterday,
      reason: 'low_energy',
    );
    final missed = await habits.getMissedHabitsForDate(yesterday);
    expect(missed.map((h) => h.habitId), [b]);
  });

  test('deleteHabit removes its completions and reflections too', () async {
    final id = await addHabit('Workout');
    await habits.setCompleted(id, today);
    await db.reflectionDao.createHabitReflection(
      habitId: id,
      missedDate: today,
      reason: 'too_busy',
    );
    await habits.deleteHabit(id);
    expect(await db.habitDao.getHabitById(id), isNull);
    expect(await db.select(db.habitCompletions).get(), isEmpty);
    expect(await db.select(db.habitReflections).get(), isEmpty);
  });
}
