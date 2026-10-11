import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/extensions/date_extensions.dart';
import 'package:habit_tracker/core/providers/current_date_provider.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/models/habit_models.dart';
import 'package:habit_tracker/data/services/database_service.dart';
import 'package:habit_tracker/data/services/reflection_gate_service.dart';
import 'package:habit_tracker/features/reflection/presentation/widgets/pause_and_reflect_sheet.dart';
import 'package:habit_tracker/features/reflection/presentation/widgets/reflection_taxonomy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCurrentDateNotifier extends CurrentDateNotifier {
  _FakeCurrentDateNotifier(this._date);
  final DateTime _date;

  @override
  DateTime build() => _date;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reflection_taxonomy', () {
    test('resolveFollowUp returns triggering reason key and question', () {
      final res = resolveFollowUp(['meetings', 'low_energy']);
      expect(res, isNotNull);
      expect(res!.triggerReasonKey, 'low_energy');
      expect(res.followUp.question, 'How was your energy?');
      expect(res.followUp.options, ['Great', 'Okay', 'Very Low']);
    });

    test('resolveFollowUp returns null when no reasons trigger follow-up', () {
      final res = resolveFollowUp(['meetings', 'weather']);
      expect(res, isNull);
    });

    test('findReasonLabel returns human label', () {
      expect(findReasonLabel('low_energy'), 'Low Energy');
      expect(findReasonLabel('felt_overwhelmed'), 'Overwhelmed');
    });
  });

  group('PauseAndReflectSheet Widget', () {
    late AppDatabase db;
    final fixedToday = DateTime(2026, 10, 11);
    final yesterday = fixedToday.addDays(-1);

    final testMissedHabits = [
      const HabitWithCompletion(
        habitId: 101,
        name: 'Morning Meditation',
        emoji: 'self_improvement',
        categoryName: 'Mind',
        categoryEmoji: 'psychology',
        categoryColorValue: 0xFF6B5B8C,
        frequencyType: 'daily',
        frequencyConfig: null,
        isCompletedToday: false,
        sortOrder: 0,
      ),
    ];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
        'renders title according to targetDate and disables Continue initially',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentDateProvider.overrideWith(
              () => _FakeCurrentDateNotifier(fixedToday),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    PauseAndReflectSheet.show(
                      context: context,
                      targetDate: yesterday,
                      missedHabits: testMissedHabits,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Check title for yesterday
      expect(find.text('What got in the way yesterday?'), findsOneWidget);
      expect(find.text('No judgment. Just noticing.'), findsOneWidget);
      expect(find.text('Left for another day: '), findsOneWidget);
      expect(find.text('Morning Meditation'), findsOneWidget);
      expect(find.text('Choose up to two'), findsOneWidget);

      // Continue button should be disabled (onPressed == null)
      final continueButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue'),
      );
      expect(continueButton.onPressed, isNull);
    });

    testWidgets(
        'enforcing max 2 reasons drops oldest FIFO and enables Continue',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentDateProvider.overrideWith(
              () => _FakeCurrentDateNotifier(fixedToday),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    PauseAndReflectSheet.show(
                      context: context,
                      targetDate: fixedToday,
                      missedHabits: testMissedHabits,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // For today, title is today
      expect(find.text('What got in the way today?'), findsOneWidget);

      // Select 1st reason: Low Energy
      await tester.ensureVisible(find.text('Low Energy'));
      await tester.tap(find.text('Low Energy'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);

      // Continue button should now be enabled
      var continueButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue'),
      );
      expect(continueButton.onPressed, isNotNull);

      // Select 2nd reason: Poor Sleep
      await tester.ensureVisible(find.text('Poor Sleep'));
      await tester.tap(find.text('Poor Sleep'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);

      // Select 3rd reason: Felt Sick -> drops Low Energy (oldest)
      await tester.ensureVisible(find.text('Felt Sick'));
      await tester.tap(find.text('Felt Sick'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      // Stones strip should contain Poor Sleep and Felt Sick
      expect(find.text('Poor Sleep'), findsWidgets);
      expect(find.text('Felt Sick'), findsWidgets);
    });

    testWidgets('saving upserts reflection row and clears skipped date',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Mark yesterday as skipped initially
      await ReflectionGateService.markDateSkipped(yesterday);
      expect(await ReflectionGateService.isDateSkipped(yesterday), isTrue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentDateProvider.overrideWith(
              () => _FakeCurrentDateNotifier(fixedToday),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    PauseAndReflectSheet.show(
                      context: context,
                      targetDate: yesterday,
                      missedHabits: testMissedHabits,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Low Energy
      await tester.ensureVisible(find.text('Low Energy'));
      await tester.tap(find.text('Low Energy'));
      await tester.pumpAndSettle();

      // Answer follow-up
      expect(find.text('How was your energy?'), findsOneWidget);
      await tester.ensureVisible(find.text('Very Low'));
      await tester.tap(find.text('Very Low'));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Sheet should be popped
      expect(find.text('What got in the way yesterday?'), findsNothing);

      // Database should contain exactly one row for yesterday
      final reflection = await db.reflectionDao.getReflectionForDate(yesterday);
      expect(reflection, isNotNull);
      final reasonKeys =
          (jsonDecode(reflection!.reasonKeys) as List).cast<String>();
      expect(reasonKeys, ['low_energy']);
      expect(reflection.followUpReasonKey, 'low_energy');
      expect(reflection.followUpAnswer, 'Very Low');

      // Skipped date registry should be cleared
      expect(await ReflectionGateService.isDateSkipped(yesterday), isFalse);
    });

    testWidgets(
        'existing reflection shows Clear reflection in header and deletes row on tap',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pre-seed an existing reflection for today
      await db.reflectionDao.upsertReflection(
        reflectionDate: fixedToday,
        reasonKeys: ['poor_sleep'],
        missedHabitIds: [101],
      );
      expect(
        await db.reflectionDao.getReflectionForDate(fixedToday),
        isNotNull,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentDateProvider.overrideWith(
              () => _FakeCurrentDateNotifier(fixedToday),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    PauseAndReflectSheet.show(
                      context: context,
                      targetDate: fixedToday,
                      missedHabits: testMissedHabits,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Clear reflection button should be present in header
      expect(find.text('Clear reflection'), findsOneWidget);

      // Tap Clear reflection
      await tester.tap(find.text('Clear reflection'));
      await tester.pumpAndSettle();

      // Sheet should be popped
      expect(find.text('What got in the way today?'), findsNothing);

      // Reflection should now be completely deleted from the database
      expect(await db.reflectionDao.getReflectionForDate(fixedToday), isNull);
    });

    testWidgets(
        'removing all stones switches button to Clear reflection and deletes row',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Pre-seed an existing reflection for today
      await db.reflectionDao.upsertReflection(
        reflectionDate: fixedToday,
        reasonKeys: ['low_energy'],
        missedHabitIds: [101],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentDateProvider.overrideWith(
              () => _FakeCurrentDateNotifier(fixedToday),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    PauseAndReflectSheet.show(
                      context: context,
                      targetDate: fixedToday,
                      missedHabits: testMissedHabits,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Initially has 1 stone, button says Continue
      expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);

      // Remove the stone by tapping close icon on the stone chip
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Now 0 stones: footer button switches to 'Clear reflection'
      expect(
        find.widgetWithText(ElevatedButton, 'Clear reflection'),
        findsOneWidget,
      );

      // Tap the bottom Clear reflection button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Clear reflection'));
      await tester.pumpAndSettle();

      // Sheet should be popped and row deleted
      expect(find.text('What got in the way today?'), findsNothing);
      expect(await db.reflectionDao.getReflectionForDate(fixedToday), isNull);
    });
  });
}
