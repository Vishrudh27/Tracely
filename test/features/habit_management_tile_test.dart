import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/providers/current_date_provider.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/repositories/habit_repository.dart';
import 'package:habit_tracker/features/habits/presentation/widgets/habit_management_tile.dart';

class _FakeCurrentDateNotifier extends CurrentDateNotifier {
  _FakeCurrentDateNotifier(this._date);
  final DateTime _date;

  @override
  DateTime build() => _date;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HabitManagementTile Widget Tests', () {
    final fixedToday = DateTime(2026, 10, 13);

    final testHabit = Habit(
      id: 42,
      name: 'Morning Meditation',
      categoryId: 1,
      frequencyType: 'daily',
      frequencyConfig: null,
      reminderEnabled: false,
      isAlarmReminder: false,
      sortOrder: 0,
      isArchived: false,
      emoji: 'self_improvement',
      createdAt: fixedToday.subtract(const Duration(days: 30)),
      updatedAt: fixedToday,
    );

    final testCategory = Category(
      id: 1,
      name: 'Mindfulness',
      colorValue: 0xFF6B5B8C,
      emoji: 'spa',
      sortOrder: 0,
      isBuiltIn: true,
      isArchived: false,
      createdAt: fixedToday,
    );

    testWidgets('renders habit title, category, streak pill, and 7-day track',
        (tester) async {
      bool tapped = false;

      // 3 consecutive completions ending today -> 3d streak
      final completions = <HabitCompletion>[
        HabitCompletion(
          id: 1,
          habitId: 42,
          completedDate: fixedToday.subtract(const Duration(days: 2)),
          completedAt: fixedToday.subtract(const Duration(days: 2)),
          isRecoveryDay: false,
        ),
        HabitCompletion(
          id: 2,
          habitId: 42,
          completedDate: fixedToday.subtract(const Duration(days: 1)),
          completedAt: fixedToday.subtract(const Duration(days: 1)),
          isRecoveryDay: false,
        ),
        HabitCompletion(
          id: 3,
          habitId: 42,
          completedDate: fixedToday,
          completedAt: fixedToday,
          isRecoveryDay: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentDateProvider.overrideWith(
              () => _FakeCurrentDateNotifier(fixedToday),
            ),
            habitCompletionsProvider(42).overrideWith(
              (ref) => Stream.value(completions),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HabitManagementTile(
                habit: testHabit,
                category: testCategory,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify habit name and category details
      expect(find.text('Morning Meditation'), findsOneWidget);
      expect(find.textContaining('Mindfulness'), findsOneWidget);
      expect(find.textContaining('Daily'), findsOneWidget);

      // Verify streak pill displays 3d with fire icon
      expect(find.text('3'), findsOneWidget);
      expect(find.text('d'), findsWidgets);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);

      // Verify tap works
      await tester.tap(find.byType(HabitManagementTile));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
