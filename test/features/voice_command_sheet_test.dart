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

  testWidgets('typed "add running every morning at 6" creates the habit',
      (tester) async {
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

  testWidgets('unknown text shows examples and keeps Confirm disabled',
      (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField).first, "what's the weather");
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.voiceUnknownTitle), findsOneWidget);
    final confirm = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(confirm.onPressed, isNull);
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
