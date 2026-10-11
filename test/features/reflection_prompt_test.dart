import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/extensions/date_extensions.dart';
import 'package:habit_tracker/core/providers/current_date_provider.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/services/database_service.dart';
import 'package:habit_tracker/data/services/reflection_gate_service.dart';
import 'package:habit_tracker/features/reflection/presentation/providers/reflection_prompt_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCurrentDateNotifier extends CurrentDateNotifier {
  _FakeCurrentDateNotifier(this._date);
  final DateTime _date;

  @override
  DateTime build() => _date;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReflectionGateService (v2)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('auto-open is offered at most once per calendar day', () async {
      final today = DateTime(2026, 10, 11);
      expect(
        await ReflectionGateService.hasAutoOpenBeenOfferedToday(today),
        isFalse,
      );

      await ReflectionGateService.markAutoOpenOffered(today);

      expect(
        await ReflectionGateService.hasAutoOpenBeenOfferedToday(today),
        isTrue,
      );

      // Next day is not blocked
      final tomorrow = today.addDays(1);
      expect(
        await ReflectionGateService.hasAutoOpenBeenOfferedToday(tomorrow),
        isFalse,
      );
    });

    test('skipped dates are tracked per calendar date', () async {
      final date = DateTime(2026, 10, 10);
      expect(await ReflectionGateService.isDateSkipped(date), isFalse);

      await ReflectionGateService.markDateSkipped(date);
      expect(await ReflectionGateService.isDateSkipped(date), isTrue);

      await ReflectionGateService.clearDateSkipped(date);
      expect(await ReflectionGateService.isDateSkipped(date), isFalse);
    });
  });

  group('reflectionPromptStateProvider', () {
    late AppDatabase db;
    late ProviderContainer container;
    final fixedToday = DateTime(2026, 10, 11, 19, 0); // 19:00 (evening)
    final fixedYesterday = fixedToday.addDays(-1);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentDateProvider.overrideWith(
            () => _FakeCurrentDateNotifier(fixedToday.startOfDay),
          ),
          nowFnProvider.overrideWithValue(() => fixedToday),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('returns none when there are no habits at all', () async {
      final state =
          await container.read(reflectionPromptStateProvider.future);
      expect(state, ReflectionPromptState.none);
    });

    test('returns morningAfter when yesterday had missed habits', () async {
      final categoryId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Health',
              emoji: 'favorite',
              colorValue: 0xFF5A7233,
            ),
          );

      // Habit created before yesterday
      await db.into(db.habits).insert(
            HabitsCompanion.insert(
              name: 'Drink Water',
              categoryId: categoryId,
              createdAt: Value(fixedYesterday.addDays(-2)),
            ),
          );

      final state =
          await container.read(reflectionPromptStateProvider.future);
      expect(state, ReflectionPromptState.morningAfter);
    });

    test('morningAfter takes priority even in the evening', () async {
      final categoryId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Health',
              emoji: 'favorite',
              colorValue: 0xFF5A7233,
            ),
          );

      await db.into(db.habits).insert(
            HabitsCompanion.insert(
              name: 'Exercise',
              categoryId: categoryId,
              createdAt: Value(fixedYesterday.addDays(-2)),
            ),
          );

      final state =
          await container.read(reflectionPromptStateProvider.future);
      expect(state, ReflectionPromptState.morningAfter);
    });

    test('returns evening when yesterday is logged/clean and today is incomplete',
        () async {
      final categoryId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Health',
              emoji: 'favorite',
              colorValue: 0xFF5A7233,
            ),
          );

      final habitId = await db.into(db.habits).insert(
            HabitsCompanion.insert(
              name: 'Exercise',
              categoryId: categoryId,
              createdAt: Value(fixedYesterday.addDays(-2)),
            ),
          );

      // Yesterday was completed
      await db.into(db.habitCompletions).insert(
            HabitCompletionsCompanion.insert(
              habitId: habitId,
              completedDate: fixedYesterday.startOfDay,
            ),
          );

      final state =
          await container.read(reflectionPromptStateProvider.future);
      expect(state, ReflectionPromptState.evening);
    });

    test('skipping yesterday transitions state away from morningAfter',
        () async {
      final categoryId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Health',
              emoji: 'favorite',
              colorValue: 0xFF5A7233,
            ),
          );

      await db.into(db.habits).insert(
            HabitsCompanion.insert(
              name: 'Exercise',
              categoryId: categoryId,
              createdAt: Value(fixedYesterday.addDays(-2)),
            ),
          );

      expect(
        await container.read(reflectionPromptStateProvider.future),
        ReflectionPromptState.morningAfter,
      );

      // Skip yesterday
      await container
          .read(reflectionPromptStateProvider.notifier)
          .skip(fixedYesterday);

      // Now at 19:00 with today incomplete, transitions to evening
      expect(
        await container.read(reflectionPromptStateProvider.future),
        ReflectionPromptState.evening,
      );
    });
  });
}
