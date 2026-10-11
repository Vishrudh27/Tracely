import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/voice_command_parser.dart';

/// Online Voice Command Parser service powered by Gemini API (Gemini 2.0 Flash).
///
/// Sends user speech text to Gemini API with JSON Schema mode enabled.
/// Converts the structured JSON response into a [VoiceCommand] instance.
/// If network is unavailable, API key is missing, or request fails, returns null
/// to allow fallback to the local regex parser.
class GeminiVoiceService {
  /// Priority list of Gemini models for voice command parsing.
  /// Lite models are prioritized for instant voice latency (< 800ms) and 99.9% uptime,
  /// followed by general flash models for failover.
  static const List<String> candidateModels = [
    'gemini-flash-lite-latest',
    'gemini-3.5-flash-lite',
    'gemini-3.5-flash',
    'gemini-flash-latest',
  ];

  /// Persistent HTTP client for connection pooling and TLS session reuse (saves 200-400ms per call).
  static final http.Client _client = http.Client();

  /// Set to false to disable online Gemini API calls.
  static bool enabled = true;

  /// Custom override for testing.
  @visibleForTesting
  static Future<VoiceCommand?> Function(String input)? testOverride;

  /// Resolves the Gemini API Key from compile-time environment or local `.env` file.
  static Future<String?> getApiKey() async {
    const compileTimeKey = String.fromEnvironment('GEMINI_API_KEY');
    if (compileTimeKey.isNotEmpty) {
      return compileTimeKey;
    }

    try {
      final envFile = File('.env');
      if (await envFile.exists()) {
        final lines = await envFile.readAsLines();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('GEMINI_API_KEY=')) {
            final val = trimmed.substring('GEMINI_API_KEY='.length).trim();
            if (val.isNotEmpty) {
              return val;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('GeminiVoiceService: Error reading .env file: $e');
    }

    return null;
  }

  /// Parses spoken/typed [input] text into a structured [VoiceCommand] using Gemini.
  static Future<VoiceCommand?> parseVoiceCommand(
    String input, {
    required DateTime today,
    required int nowMinute,
    List<String> existingHabits = const [],
    List<String> existingTasks = const [],
    List<String> existingCategories = const [],
    String? customApiKey,
  }) async {
    if (testOverride != null) {
      return testOverride!(input);
    }

    if (!enabled ||
        (customApiKey == null &&
            !kIsWeb &&
            Platform.environment.containsKey('FLUTTER_TEST'))) {
      return null;
    }

    final apiKey = customApiKey ?? await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('GeminiVoiceService: No API key found, skipping online parse.');
      return null;
    }

    final todayFormatted =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final prompt = '''
You are Tracely's AI Voice Assistant parser.
Parse the user's spoken or typed input into clean structured JSON.

User Input: "$input"
Today's Date: $todayFormatted
Current Time (minutes past midnight): $nowMinute
${existingHabits.isNotEmpty ? 'Existing User Habits: ${jsonEncode(existingHabits)}' : ''}
${existingTasks.isNotEmpty ? 'Existing User Tasks: ${jsonEncode(existingTasks)}' : ''}
${existingCategories.isNotEmpty ? 'Existing User Categories: ${jsonEncode(existingCategories)}' : ''}

CRITICAL MATCHING & EXTRACTION RULES:
1. If the user mentions an action on an existing habit or task (complete, miss, delete), match the "text" field EXACTLY to one of the Existing User Habits/Tasks if a match exists (e.g., if user says "did my morning run" and existing habit is "Running", output "Running").
2. For new habits/tasks ("createHabit", "createReminderTask"), the "text" field MUST contain ONLY the clean title (Title Case, e.g., "Learning", "Daily Jog", "Call Mom"). Strip ALL framing words like "create a habit of", "remind me to", "call reminder at daily 7pm".

FEW-SHOT EXAMPLES:
- Input: "create an habot of learning and add a reminder of like call reminder at daily 7 pm"
  Output: {"intent": "createHabit", "text": "Learning", "frequencyType": "daily", "minuteOfDay": 1140, "isCallReminder": true}

- Input: "mark my morning workout as done"
  Output: {"intent": "completeHabit", "text": "Morning Workout", "frequencyType": "daily", "isCallReminder": false}

- Input: "missed reading because I was super tired"
  Output: {"intent": "logMiss", "text": "Reading", "reasonKey": "low_energy", "frequencyType": "daily", "isCallReminder": false}

- Input: "remind me to call dad tomorrow at 5pm with a phone call alarm"
  Output: {"intent": "createReminderTask", "text": "Call Dad", "minuteOfDay": 1020, "isCallReminder": true, "frequencyType": "daily"}

Allowed Intents: "createHabit", "createReminderTask", "completeHabit", "logMiss", "deleteItem", "unknown".

Rules:
1. If user asks to create/start/track a recurring habit, intent = "createHabit".
2. If intent is "createHabit":
   - "frequencyType" can be "daily" or "specific_days".
   - "specificDays" is an array of ints 1..7 (Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7).
3. If intent is "createReminderTask":
   - "dateStr" should be YYYY-MM-DD if specified or relative (e.g. tomorrow).
4. If user mentions a time like "7 pm", minuteOfDay = 1140. If "9 am", minuteOfDay = 540.
5. "isCallReminder" is true if user mentions "call reminder", "call alarm", "ring me", or "phone call".
6. If intent is "logMiss":
   - "reasonKey" should be one of: "low_energy", "too_busy", "felt_sick", "weather", "poor_sleep", "burned_out", "mental_break", "needed_rest", "emergency", "forgot", "custom".
   - "reasonText" stores custom reason words if not matching standard keys.
''';

    final body = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.1,
        "maxOutputTokens": 120,
        "responseMimeType": "application/json",
        "responseSchema": {
          "type": "OBJECT",
          "properties": {
            "intent": {
              "type": "STRING",
              "enum": [
                "createHabit",
                "createReminderTask",
                "completeHabit",
                "logMiss",
                "deleteItem",
                "unknown"
              ]
            },
            "text": {
              "type": "STRING",
              "description": "Cleaned habit/task title or target phrase"
            },
            "frequencyType": {
              "type": "STRING",
              "enum": ["daily", "specific_days"]
            },
            "specificDays": {
              "type": "ARRAY",
              "items": {"type": "INTEGER"}
            },
            "minuteOfDay": {"type": "INTEGER", "nullable": true},
            "dateStr": {"type": "STRING", "nullable": true},
            "reasonKey": {"type": "STRING", "nullable": true},
            "reasonText": {"type": "STRING", "nullable": true},
            "target": {"type": "STRING", "nullable": true},
            "isCallReminder": {"type": "BOOLEAN"}
          },
          "required": ["intent", "text", "frequencyType", "isCallReminder"]
        }
      }
    };

    final encodedBody = jsonEncode(body);

    for (final model in candidateModels) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      try {
        final response = await _client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: encodedBody,
            )
            .timeout(const Duration(milliseconds: 2500));

        if (response.statusCode == 200) {
          final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = jsonMap['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) continue;

          final content = candidates[0]['content'];
          if (content == null) continue;

          final parts = content['parts'] as List?;
          if (parts == null || parts.isEmpty) continue;

          final jsonText = parts[0]['text'] as String?;
          if (jsonText == null || jsonText.isEmpty) continue;

          final parsedData = jsonDecode(jsonText) as Map<String, dynamic>;
          debugPrint('GeminiVoiceService: Parsed successfully with model $model');
          return _mapToVoiceCommand(parsedData, today: today);
        } else if (response.statusCode == 503 ||
            response.statusCode == 429 ||
            response.statusCode == 500) {
          debugPrint(
            'GeminiVoiceService: Model $model returned ${response.statusCode} (high demand/rate limit). Trying next fallback model...',
          );
          continue;
        } else {
          debugPrint(
            'GeminiVoiceService API response error ${response.statusCode} on $model: ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('GeminiVoiceService API call on $model failed: $e');
      }
    }

    return null;
  }

  static VoiceCommand _mapToVoiceCommand(
    Map<String, dynamic> data, {
    required DateTime today,
  }) {
    final intentStr = data['intent'] as String? ?? 'unknown';
    final intent = VoiceIntent.values.firstWhere(
      (e) => e.name == intentStr,
      orElse: () => VoiceIntent.unknown,
    );

    if (intent == VoiceIntent.unknown) {
      return const VoiceCommand(intent: VoiceIntent.unknown);
    }

    final text = data['text'] as String? ?? '';
    final frequencyType = data['frequencyType'] as String? ?? 'daily';
    final specificDays =
        (data['specificDays'] as List?)?.map((e) => e as int).toList() ??
        const <int>[];
    final minuteOfDay = data['minuteOfDay'] as int?;

    DateTime? date;
    final dateStr = data['dateStr'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      date = DateTime.tryParse(dateStr);
    }

    final reasonKey = data['reasonKey'] as String?;
    final reasonText = data['reasonText'] as String?;
    final target = data['target'] as String?;
    final isCallReminder = data['isCallReminder'] as bool? ?? false;

    return VoiceCommand(
      intent: intent,
      text: text,
      frequencyType: frequencyType,
      specificDays: specificDays,
      minuteOfDay: minuteOfDay,
      date: date,
      reasonKey: reasonKey,
      reasonText: reasonText,
      target: target,
      isCallReminder: isCallReminder,
    );
  }
}
