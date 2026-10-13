import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/providers/current_date_provider.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/database/daos/reflection_dao.dart';
import 'package:habit_tracker/data/repositories/habit_repository.dart';
import 'package:habit_tracker/features/habits/presentation/screens/habit_detail_screen.dart';

class _FakeCurrentDateNotifier extends CurrentDateNotifier {
  _FakeCurrentDateNotifier(this._date);
  final DateTime _date;

  @override
  DateTime build() => _date;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HabitDetailScreen Widget Tests', () {
    final fixedToday = DateTime(2026, 10, 13);

    final testHabit = Habit(
      id: 99,
      name: 'Evening Reading',
      categoryId: 2,
      frequencyType: 'daily',
      frequencyConfig: null,
      reminderEnabled: false,
      isAlarmReminder: false,
      sortOrder: 0,
      isArchived: false,
      emoji: 'menu_book',
      createdAt: fixedToday.subtract(const Duration(days: 30)),
      updatedAt: fixedToday,
    );

    final testCategory = Category(
      id: 2,
      name: 'Knowledge',
      colorValue: 0xFF3F6480,
      emoji: 'school',
      sortOrder: 0,
      isBuiltIn: true,
      isArchived: false,
      createdAt: fixedToday,
    );

    testWidgets('renders Hero Momentum Gauge, 28-day calendar, and why statistics',
        (tester) async {
      final completions = <HabitCompletion>[
        HabitCompletion(
          id: 1,
          habitId: 99,
          completedDate: fixedToday.subtract(const Duration(days: 1)),
          completedAt: fixedToday.subtract(const Duration(days: 1)),
          isRecoveryDay: false,
        ),
        HabitCompletion(
          id: 2,
          habitId: 99,
          completedDate: fixedToday,
          completedAt: fixedToday,
          isRecoveryDay: false,
        ),
      ];

      final reasons = <ReasonFrequency>[
        const ReasonFrequency(reason: 'low_energy', count: 3),
        const ReasonFrequency(reason: 'too_busy', count: 1),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentDateProvider.overrideWith(
              () => _FakeCurrentDateNotifier(fixedToday),
            ),
            habitByIdProvider(99).overrideWith(
              (ref) => Stream.value(testHabit),
            ),
            categoryByIdProvider(2).overrideWith(
              (ref) => Future.value(testCategory),
            ),
            habitCompletionsProvider(99).overrideWith(
              (ref) => Stream.value(completions),
            ),
            habitReasonsProvider(99).overrideWith(
              (ref) => Stream.value(reasons),
            ),
            habitReflectionsMapProvider(99).overrideWith(
              (ref) => Stream.value(const {}),
            ),
          ],
          child: const MaterialApp(
            home: HabitDetailScreen(habitId: 99),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Identity
      expect(find.text('Evening Reading'), findsOneWidget);
      expect(find.textContaining('Knowledge'), findsOneWidget);

      // 2. Verify Hero Momentum Gauge
      expect(find.text('CURRENT STREAK'), findsOneWidget);
      expect(find.text('All-Time Best'), findsOneWidget);
      expect(find.text('Consistency'), findsOneWidget);
      expect(find.text('Bounce-Back'), findsOneWidget);

      // 3. Verify Calendar Grid Section
      expect(find.text('Past 4 Weeks History'), findsOneWidget);

      // 4. Verify Why Statistics & Resilience
      expect(find.text('Why it slipped & Resilience'), findsOneWidget);
      expect(find.textContaining('Bounce-Back Rate'), findsOneWidget);
      expect(find.text('PRIMARY OBSTACLE'), findsOneWidget);
      expect(find.textContaining('Low energy'), findsWidgets);
    });
  });
}
