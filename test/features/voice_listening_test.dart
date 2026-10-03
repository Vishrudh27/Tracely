import 'dart:convert';

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

class _FixedDate extends CurrentDateNotifier {
  @override
  DateTime build() => DateTime(2026, 9, 23);
}

/// The spoken path, driven by fake Android recognizer callbacks. Its own
/// file because SpeechToText is a singleton: once initialize() succeeds it
/// stays initialized for the isolate, which would break the no-mic test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const speech = 'plugin.csdcorp.com/speech_to_text';
  const silence = Duration(seconds: 3);
  late AppDatabase db;
  late List<String> calls;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // The sheet reads remembered category corrections on open.
    SharedPreferences.setMockInitialValues({});
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(speech), (call) async {
          calls.add(call.method);
          return call.method == 'locales' ? <String>[] : true;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(speech), null);
    await db.close();
  });

  /// Delivers a callback the way the native plugin does.
  Future<void> native(WidgetTester tester, String method, String arg) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      speech,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, arg)),
      (_) {},
    );
    await tester.pump();
  }

  String words(String text, {bool isFinal = false}) => jsonEncode({
    'alternates': [
      {'recognizedWords': text, 'confidence': 0.9},
    ],
    'resultType': isFinal ? 2 : 0,
  });

  /// A final result carrying several alternate transcriptions, most
  /// confident first — what Android sends when it's unsure.
  String alternates(List<String> texts) => jsonEncode({
    'alternates': [
      for (final t in texts) {'recognizedWords': t, 'confidence': 0.9},
    ],
    'resultType': 2,
  });

  /// One Android session: partial, final, mic closed.
  Future<void> segment(WidgetTester tester, String text) async {
    await native(tester, 'notifyStatus', 'listening');
    await native(tester, 'textRecognition', words(text));
    await native(tester, 'textRecognition', words(text, isFinal: true));
    await native(tester, 'notifyStatus', 'notListening');
    await native(tester, 'notifyStatus', 'done');
  }

  Finder field(String text) => find.widgetWithText(TextField, text);

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

  testWidgets('keeps listening across a pause and joins both sentences', (
    tester,
  ) async {
    await openSheet(tester);
    await segment(tester, 'add the habit of reading');

    // Android closed the mic at the pause — the sheet must not parse yet.
    expect(find.text('New habit'), findsNothing);
    expect(calls.where((c) => c == 'listen'), hasLength(2));

    await tester.pump(const Duration(seconds: 1));
    await segment(tester, 'every day at 9 pm');
    expect(field('add the habit of reading every day at 9 pm'), findsOneWidget);

    await tester.pump(silence);
    await tester.pumpAndSettle();
    expect(find.text('New habit'), findsOneWidget);
    expect(field('Reading'), findsOneWidget);
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('9:00 PM'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('tapping the mic on a draft appends instead of restarting', (
    tester,
  ) async {
    await openSheet(tester);
    await segment(tester, 'add running');
    await tester.pump(silence);
    await tester.pumpAndSettle();
    expect(find.text('New habit'), findsOneWidget);

    // Mic again — must keep "add running" and dictate onto the end.
    await tester.tap(find.bySemanticsLabel('Start listening'));
    await tester.pumpAndSettle();
    await native(tester, 'notifyStatus', 'listening');

    // A pause before speaking must NOT end the mic (the bug).
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('New habit'), findsNothing);

    await native(tester, 'textRecognition', words('every day at 9 pm'));
    await native(
      tester,
      'textRecognition',
      words('every day at 9 pm', isFinal: true),
    );
    await native(tester, 'notifyStatus', 'notListening');
    expect(field('add running every day at 9 pm'), findsOneWidget);

    await tester.pump(silence);
    await tester.pumpAndSettle();
    expect(field('Running'), findsOneWidget);
    expect(find.text('9:00 PM'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('an empty final result keeps the spoken words', (tester) async {
    await openSheet(tester);
    await native(tester, 'notifyStatus', 'listening');
    await native(
      tester,
      'textRecognition',
      words('add running every morning at 6'),
    );
    await native(tester, 'textRecognition', words('', isFinal: true));
    await native(tester, 'notifyStatus', 'notListening');
    expect(field('add running every morning at 6'), findsOneWidget);

    await tester.pump(silence);
    await tester.pumpAndSettle();
    expect(field('Running'), findsOneWidget);
    expect(find.text('6:00 AM'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a final result after the mic closed is still used', (
    tester,
  ) async {
    await openSheet(tester);
    await native(tester, 'notifyStatus', 'listening');
    await native(tester, 'notifyStatus', 'notListening');
    await native(tester, 'notifyStatus', 'doneNoResult');
    await native(
      tester,
      'textRecognition',
      words('add running', isFinal: true),
    );

    await tester.pump(silence);
    await tester.pumpAndSettle();
    expect(field('Running'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('words are used when Android never sends a final result', (
    tester,
  ) async {
    await openSheet(tester);
    await native(tester, 'notifyStatus', 'listening');
    await native(tester, 'textRecognition', words('add running'));
    await native(tester, 'notifyStatus', 'notListening');

    // Grace for a late final, then a restart, then the silence window.
    await tester.pump(const Duration(seconds: 2));
    expect(calls.where((c) => c == 'listen'), hasLength(2));
    await tester.pump(silence);
    await tester.pumpAndSettle();
    expect(field('Running'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('tapping stop parses right away', (tester) async {
    await openSheet(tester);
    await native(tester, 'notifyStatus', 'listening');
    await native(tester, 'textRecognition', words('add running'));

    await tester.tap(find.bySemanticsLabel('Stop listening'));
    await tester.pumpAndSettle();
    expect(field('Running'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets(
    'a top transcription that fails to parse is retried against its alternates',
    (tester) async {
      await openSheet(tester);
      await native(tester, 'notifyStatus', 'listening');
      await native(tester, 'textRecognition', words("what's the weather"));
      await native(
        tester,
        'textRecognition',
        alternates(["what's the weather", 'add running every morning at 6']),
      );
      await native(tester, 'notifyStatus', 'notListening');

      await tester.pump(silence);
      await tester.pumpAndSettle();
      expect(find.text('New habit'), findsOneWidget);
      expect(field('Running'), findsOneWidget);
      expect(find.text('6:00 AM'), findsOneWidget);
      await _unmount(tester);
    },
  );

  testWidgets('stale alternates are ignored once a later segment adds words', (
    tester,
  ) async {
    await openSheet(tester);
    await native(tester, 'notifyStatus', 'listening');
    await native(tester, 'textRecognition', words('add running'));
    await native(
      tester,
      'textRecognition',
      alternates(['add running', "what's the weather"]),
    );
    await native(tester, 'notifyStatus', 'notListening');

    // A second segment appends more words, with no final result of its own
    // — the first segment's alternates are still sitting in state and must
    // not be blindly reused; the full text parses fine on its own anyway.
    await native(tester, 'notifyStatus', 'listening');
    await native(tester, 'textRecognition', words('every day at 9 pm'));
    await tester.tap(find.bySemanticsLabel('Stop listening'));
    await tester.pumpAndSettle();

    expect(find.text('New habit'), findsOneWidget);
    expect(field('Running'), findsOneWidget);
    expect(find.text('9:00 PM'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('falls back to on-device when the online recognizer errors', (
    tester,
  ) async {
    await openSheet(tester);
    // Online is tried first; show the notice for it.
    expect(find.text(AppStrings.voiceOnlineNotice), findsOneWidget);
    await native(tester, 'notifyStatus', 'listening');
    await native(tester, 'notifyStatus', 'notListening');
    await native(
      tester,
      'notifyError',
      jsonEncode({'errorMsg': 'error_network', 'permanent': true}),
    );
    await tester.pump();

    // Retried on-device, not given up on.
    expect(calls.where((c) => c == 'listen'), hasLength(2));
    expect(find.text(AppStrings.voiceRecognizerFailed), findsNothing);
    await _unmount(tester);
  });

  testWidgets(
    'a stale-looking error before listening is confirmed is recovered by '
    'the watchdog, not dropped for good',
    (tester) async {
      await openSheet(tester);
      // No 'listening' status first — _segmentConfirmed is still false, so
      // this error is treated as a possible straggler from a previous
      // segment and ignored, rather than ending the segment on its own.
      await native(
        tester,
        'notifyError',
        jsonEncode({'errorMsg': 'error_network', 'permanent': true}),
      );
      await tester.pump();
      expect(calls.where((c) => c == 'listen'), hasLength(1));

      // The watchdog, armed when listen() first resolved, still catches the
      // stuck segment and retries — the dropped error must not also have
      // cancelled it.
      await tester.pump(const Duration(seconds: 3));
      expect(calls.where((c) => c == 'listen'), hasLength(2));
      expect(find.text(AppStrings.voiceRecognizerFailed), findsNothing);
      await _unmount(tester);
    },
  );

  testWidgets(
    'does not ping-pong forever with no network and no offline pack',
    (tester) async {
      await openSheet(tester);
      await native(tester, 'notifyStatus', 'listening');
      await native(tester, 'notifyStatus', 'notListening');
      await native(
        tester,
        'notifyError',
        jsonEncode({'errorMsg': 'error_network', 'permanent': true}),
      );
      await tester.pump();
      expect(calls.where((c) => c == 'listen'), hasLength(2));

      // The on-device retry also fails — no offline pack installed either.
      await native(tester, 'notifyStatus', 'listening');
      await native(tester, 'notifyStatus', 'notListening');
      await native(
        tester,
        'notifyError',
        jsonEncode({
          'errorMsg': 'error_language_unavailable',
          'permanent': true,
        }),
      );
      await tester.pump();

      // Capped at one switch — fails instead of bouncing back online.
      expect(calls.where((c) => c == 'listen'), hasLength(2));
      expect(find.text(AppStrings.voiceRecognizerFailed), findsOneWidget);
      await _unmount(tester);
    },
  );

  testWidgets('recovers from a silently stuck recognizer instead of hanging on '
      '"Listening…" forever', (tester) async {
    await openSheet(tester);
    // No native callback at all — listen() "succeeded" but the native side
    // silently never started (already busy, or not yet initialized).
    await tester.pump(const Duration(seconds: 3));
    // One retry.
    expect(calls.where((c) => c == 'listen'), hasLength(2));
    expect(find.text(AppStrings.voiceMicBusy), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    // The retry was silent too — surfaced instead of hanging.
    expect(find.text(AppStrings.voiceMicBusy), findsOneWidget);
    await _unmount(tester);
  });
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump(const Duration(milliseconds: 10));
}
