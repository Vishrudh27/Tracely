import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/constants/app_strings.dart';
import 'package:habit_tracker/core/providers/current_date_provider.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/services/database_service.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/voice_command_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// No midnight timer or lifecycle observer — just a fixed day.
class _FixedDate extends CurrentDateNotifier {
  @override
  DateTime build() => DateTime(2026, 9, 23);
}

/// The typed path end to end: no microphone in tests, so speech fails to
/// start and the sheet must still parse typed text, show an editable card,
/// and write the habit on Confirm.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  // Unmocked plugin channels answer on the real event loop, which the fake
  // test clock never reaches — every await on them would hang. Answer as a
  // device with no mic and notifications denied would.
  const channels = {
    'plugin.csdcorp.com/speech_to_text': false,
    'dexterous.com/flutter/local_notifications': false,
    'flutter_timezone': 'UTC',
  };

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // The sheet reads remembered category corrections on open.
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    channels.forEach((name, reply) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => switch (call.method) {
          'pendingNotificationRequests' => <Object>[],
          'getLocalTimezone' => reply,
          'initialize' || 'requestNotificationsPermission' => reply,
          _ => null,
        },
      );
    });
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in channels.keys) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
    await db.close();
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentDateProvider.overrideWith(_FixedDate.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => VoiceCommandSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('typed "add running every morning at 6" creates the habit', (
    tester,
  ) async {
    await openSheet(tester);

    // Speech can't start without the platform plugin.
    expect(find.text(AppStrings.voiceMicUnavailable), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byType(TextField).first,
      'add running every morning at 6',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('New habit'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Running'), findsOneWidget);
    expect(find.text('6:00 AM'), findsOneWidget);

    await tester.tap(find.text(AppStrings.voiceConfirm));
    await tester.pumpAndSettle();

    final rows = await tester.runAsync(() async {
      final habits = await db.habitDao.getActiveHabits();
      final categories = await db.select(db.categories).get();
      return (habits, categories);
    });
    final (habits, categories) = rows!;
    expect(habits, hasLength(1));
    final h = habits.single;
    expect(h.name, 'Running');
    expect(h.frequencyType, 'daily');
    expect(h.reminderEnabled, isTrue);
    expect(h.reminderTime, '06:00');
    expect(categories.firstWhere((c) => c.id == h.categoryId).name, 'Fitness');

    // Sheet closed, confirmation shown.
    expect(find.text('New habit'), findsNothing);
    expect(find.textContaining('“Running” added'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('typed "delete the reading habit" deletes it after confirm', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final category = (await db.select(db.categories).get()).first;
      await db
          .into(db.habits)
          .insert(
            HabitsCompanion.insert(name: 'Reading', categoryId: category.id),
          );
    });
    await openSheet(tester);
    await tester.enterText(
      find.byType(TextField).first,
      'delete the reading habit',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Delete habit “Reading”?'), findsOneWidget);
    await tester.tap(find.text(AppStrings.voiceDelete));
    await tester.pumpAndSettle();

    final habits = await tester.runAsync(db.habitDao.getActiveHabits);
    expect(habits, isEmpty);
    expect(find.textContaining('“Reading” deleted'), findsOneWidget);
    await _unmount(tester);
  });

  Future<Category> categoryNamed(WidgetTester tester, String name) async =>
      (await tester.runAsync(
        () => (db.select(
          db.categories,
        )..where((c) => c.name.equals(name))).getSingle(),
      ))!;

  Future<Habit> newestHabit(WidgetTester tester) async =>
      (await tester.runAsync(
        () =>
            (db.select(db.habits)
                  ..orderBy([(h) => OrderingTerm.desc(h.id)])
                  ..limit(1))
                .getSingle(),
      ))!;

  Future<void> sayAndConfirm(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
  }

  testWidgets('the category follows the user’s own habits over keywords', (
    tester,
  ) async {
    final mind = await categoryNamed(tester, 'Mind');
    await tester.runAsync(
      () => db
          .into(db.habits)
          .insert(HabitsCompanion.insert(name: 'Yoga', categoryId: mind.id)),
    );
    await openSheet(tester);
    await sayAndConfirm(tester, 'add yoga at 7');
    await tester.tap(find.text(AppStrings.voiceConfirm));
    await tester.pumpAndSettle();

    // Keywords alone would say Fitness.
    expect((await newestHabit(tester)).categoryId, mind.id);
    await _unmount(tester);
  });

  testWidgets('a corrected category is remembered after the habit is gone', (
    tester,
  ) async {
    final creativity = await categoryNamed(tester, 'Creativity');
    await openSheet(tester);
    await sayAndConfirm(tester, 'add juggling');
    await tester.ensureVisible(find.text('Creativity'));
    await tester.tap(find.text('Creativity'));
    await tester.pump();
    await tester.tap(find.text(AppStrings.voiceConfirm));
    await tester.pumpAndSettle();

    final first = await newestHabit(tester);
    expect(first.categoryId, creativity.id);
    await tester.runAsync(() => db.deleteHabit(first.id));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await sayAndConfirm(tester, 'add juggling');
    await tester.tap(find.text(AppStrings.voiceConfirm));
    await tester.pumpAndSettle();

    final second = await newestHabit(tester);
    expect(second.id, isNot(first.id));
    expect(second.categoryId, creativity.id);
    await _unmount(tester);
  });

  testWidgets('“mark reading done” applies at once with Undo', (tester) async {
    final mind = await categoryNamed(tester, 'Mind');
    final id = await tester.runAsync(
      () => db
          .into(db.habits)
          .insert(HabitsCompanion.insert(name: 'Reading', categoryId: mind.id)),
    );
    final day = DateTime(2026, 9, 23);
    await openSheet(tester);
    await sayAndConfirm(tester, 'mark reading done');

    // No confirm card — applied straight away.
    expect(find.text(AppStrings.voiceConfirm), findsNothing);
    expect(find.text('“Reading” done.'), findsOneWidget);
    expect(
      await tester.runAsync(() => db.completionDao.isCompleted(id!, day)),
      isTrue,
    );

    await tester.tap(find.text(AppStrings.voiceUndo));
    await tester.pumpAndSettle();
    expect(
      await tester.runAsync(() => db.completionDao.isCompleted(id!, day)),
      isFalse,
    );
    await _unmount(tester);
  });

  testWidgets('“missed reading because tired” logs it with Undo', (
    tester,
  ) async {
    final mind = await categoryNamed(tester, 'Mind');
    final id = await tester.runAsync(
      () => db
          .into(db.habits)
          .insert(HabitsCompanion.insert(name: 'Reading', categoryId: mind.id)),
    );
    final day = DateTime(2026, 9, 23);
    await openSheet(tester);
    await sayAndConfirm(tester, 'missed reading because i was tired');

    expect(find.text(AppStrings.voiceConfirm), findsNothing);
    expect(find.text(AppStrings.voiceMissSaved), findsOneWidget);
    expect(
      await tester.runAsync(() => db.reflectionDao.getReflectedHabitIds(day)),
      contains(id),
    );

    await tester.tap(find.text(AppStrings.voiceUndo));
    await tester.pumpAndSettle();
    expect(
      await tester.runAsync(() => db.reflectionDao.getReflectedHabitIds(day)),
      isNot(contains(id)),
    );
    await _unmount(tester);
  });

  testWidgets('unknown text shows examples and keeps Confirm disabled', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField).first, "what's the weather");
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.voiceUnknownTitle), findsOneWidget);
    final confirm = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(confirm.onPressed, isNull);
    await _unmount(tester);
  });

  testWidgets(
    'tapping Send while a save is in flight does not open a second write',
    (tester) async {
      await openSheet(tester);
      await sayAndConfirm(tester, 'add running every morning at 6');
      expect(find.text('New habit'), findsOneWidget);

      // Invoke the callbacks directly, back to back with no await between
      // them — tester.tap() awaits internally and drains enough of the event
      // loop for the first save to race ahead and finish on its own, closing
      // the window this test needs to stay open.
      void tapConfirm() => tester
          .widget<ElevatedButton>(find.byType(ElevatedButton))
          .onPressed
          ?.call();
      void tapSend() => tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Send'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed
          ?.call();

      // The save is still in flight (ReminderService.requestPermission and
      // the DB write haven't resolved yet). Without the guard, Send re-parses
      // the same text and _apply flips phase back to "parsed", which would
      // let this second Confirm call start a real second write racing the
      // first.
      tapConfirm();
      tapSend();
      tapConfirm();
      // Bounded, not pumpAndSettle() — if this regresses, a duplicate
      // write's leftover snackbar/timer can keep that waiting for minutes
      // instead of failing fast on the assertion below.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final habits = await tester.runAsync(db.habitDao.getActiveHabits);
      expect(habits, hasLength(1));
      await _unmount(tester);
    },
  );

  testWidgets(
    'a save still completes and does not throw when the sheet is closed '
    'mid-write',
    (tester) async {
      await openSheet(tester);
      await sayAndConfirm(tester, 'add running every morning at 6');

      // A direct call, not tester.tap() — tap() awaits internally and drains
      // enough of the event loop to let the save race ahead and finish before
      // we ever get to unmount, which would defeat this test.
      tester
          .widget<ElevatedButton>(find.byType(ElevatedButton))
          .onPressed
          ?.call();
      // Unmount immediately, while the save is still suspended on its first
      // await — the write must still go through, and finishing the save must
      // not pop or show a snackbar on a route that's already gone.
      await _unmount(tester);
      expect(tester.takeException(), isNull);

      final habits = await tester.runAsync(db.habitDao.getActiveHabits);
      expect(habits, hasLength(1));
    },
  );

  testWidgets('a question about a habit never auto-marks it done', (
    tester,
  ) async {
    final mind = await categoryNamed(tester, 'Mind');
    final habitId = await tester.runAsync(
      () => db
          .into(db.habits)
          .insert(HabitsCompanion.insert(name: 'Reading', categoryId: mind.id)),
    );
    final day = DateTime(2026, 9, 23);
    await openSheet(tester);
    await sayAndConfirm(tester, 'is reading done');

    // Lands on the card instead of auto-completing.
    expect(find.text(AppStrings.voiceConfirm), findsOneWidget);
    expect(
      await tester.runAsync(() => db.completionDao.isCompleted(habitId!, day)),
      isFalse,
    );
    await _unmount(tester);
  });

  testWidgets(
    'a statement that happens to start with "was" still auto-applies',
    (tester) async {
      final mind = await categoryNamed(tester, 'Mind');
      final id = await tester.runAsync(
        () => db
            .into(db.habits)
            .insert(HabitsCompanion.insert(name: 'Gym', categoryId: mind.id)),
      );
      final day = DateTime(2026, 9, 23);
      await openSheet(tester);
      // Not a question — "was" here is followed by "sick", not a pronoun.
      await sayAndConfirm(tester, 'was sick so i skipped gym');

      expect(find.text(AppStrings.voiceConfirm), findsNothing);
      expect(
        await tester.runAsync(() => db.reflectionDao.getReflectedHabitIds(day)),
        contains(id),
      );
      await _unmount(tester);
    },
  );

  testWidgets(
    'a polite "can you..." command still auto-applies, not a question',
    (tester) async {
      final mind = await categoryNamed(tester, 'Mind');
      final id = await tester.runAsync(
        () => db
            .into(db.habits)
            .insert(
              HabitsCompanion.insert(name: 'Reading', categoryId: mind.id),
            ),
      );
      final day = DateTime(2026, 9, 23);
      await openSheet(tester);
      // The parser already strips "can you" as politeness filler — not a
      // question despite starting with an aux + pronoun.
      await sayAndConfirm(tester, 'can you mark reading done');

      expect(find.text(AppStrings.voiceConfirm), findsNothing);
      expect(
        await tester.runAsync(() => db.completionDao.isCompleted(id!, day)),
        isTrue,
      );
      await _unmount(tester);
    },
  );

  testWidgets('"mark X done" matches a task that is not due today', (
    tester,
  ) async {
    final taskId = await tester.runAsync(
      () => db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              title: 'Pay rent',
              dueDate: Value(DateTime(2026, 9, 20)),
            ),
          ),
    );
    await openSheet(tester);
    await sayAndConfirm(tester, 'mark pay rent done');

    // Auto-applies with Undo — single match even though it's overdue.
    expect(find.text(AppStrings.voiceConfirm), findsNothing);
    expect(find.text('“Pay rent” done.'), findsOneWidget);
    final task = await tester.runAsync(
      () =>
          (db.select(db.tasks)..where((t) => t.id.equals(taskId!))).getSingle(),
    );
    expect(task!.isDone, isTrue);
    await _unmount(tester);
  });

  testWidgets('a reason-less miss can be confirmed by picking a reason chip', (
    tester,
  ) async {
    final mind = await categoryNamed(tester, 'Mind');
    final id = await tester.runAsync(
      () => db
          .into(db.habits)
          .insert(HabitsCompanion.insert(name: 'Reading', categoryId: mind.id)),
    );
    final day = DateTime(2026, 9, 23);
    await openSheet(tester);
    // No reason word — the single-match auto-apply needs one, so this lands
    // on the card instead.
    await sayAndConfirm(tester, 'skipped reading');

    expect(find.text(AppStrings.voiceNoReason), findsOneWidget);
    final confirmBefore = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(confirmBefore.onPressed, isNull);

    // A plain tap can land on the sheet's modal barrier instead of the chip
    // depending on scroll offset — invoke the chip's own tap handler directly.
    tester
        .widget<GestureDetector>(
          find.ancestor(
            of: find.text('Forgot'),
            matching: find.byType(GestureDetector),
          ),
        )
        .onTap!();
    await tester.pump();
    await tester.tap(find.text(AppStrings.voiceConfirm));
    await tester.pumpAndSettle();

    expect(
      await tester.runAsync(() => db.reflectionDao.getReflectedHabitIds(day)),
      contains(id),
    );
    await _unmount(tester);
  });
}

/// Dispose the tree inside the test so drift's zero-delay stream-cleanup
/// timers fire before the pending-timer check.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump(const Duration(milliseconds: 10));
}
