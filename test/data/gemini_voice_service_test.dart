import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/utils/voice_command_parser.dart';
import 'package:habit_tracker/data/services/gemini_voice_service.dart';

void main() {
  group('GeminiVoiceService Tests', () {
    final today = DateTime(2026, 10, 9);
    const nowMinute = 540; // 9:00 AM

    tearDown(() {
      GeminiVoiceService.testOverride = null;
      GeminiVoiceService.enabled = true;
    });

    test('returns null when test override is not set and running under FLUTTER_TEST', () async {
      final result = await GeminiVoiceService.parseVoiceCommand(
        'add reading daily at 9am',
        today: today,
        nowMinute: nowMinute,
      );
      expect(result, isNull);
    });

    test('uses testOverride when provided', () async {
      GeminiVoiceService.testOverride = (input) async {
        return const VoiceCommand(
          intent: VoiceIntent.createHabit,
          text: 'Running',
          frequencyType: 'daily',
        );
      };

      final result = await GeminiVoiceService.parseVoiceCommand(
        'add running daily',
        today: today,
        nowMinute: nowMinute,
      );

      expect(result, isNotNull);
      expect(result!.intent, equals(VoiceIntent.createHabit));
      expect(result.text, equals('Running'));
      expect(result.frequencyType, equals('daily'));
    });

    test('local parser handles create a habit of learning and set a call reminder at 7:00 p.m. daily', () {
      final cmd = parseVoiceCommand(
        'create a habit of learning and set a call reminder at 7:00 p.m. daily',
        today: today,
        nowMinute: nowMinute,
      );
      expect(cmd.intent, equals(VoiceIntent.createHabit));
      expect(cmd.text, equals('Learning'));
      expect(cmd.minuteOfDay, equals(1140));
      expect(cmd.isCallReminder, isTrue);
      expect(cmd.frequencyType, equals('daily'));
    });

    test('online Gemini parses user phrase via candidateModels', () async {
      final key = await GeminiVoiceService.getApiKey();
      if (key == null) return; // Skip test if no API key is provided locally

      final result = await GeminiVoiceService.parseVoiceCommand(
        'create a habit of learning and set a call reminder at 7:00 p.m. daily',
        today: today,
        nowMinute: nowMinute,
      );

      expect(result, isNotNull);
      expect(result!.intent, equals(VoiceIntent.createHabit));
      expect(result.text, equals('Learning'));
      expect(result.isCallReminder, isTrue);
      expect(result.minuteOfDay, equals(1140));
    });
  });
}
