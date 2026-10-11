import 'package:shared_preferences/shared_preferences.dart';

import '../../core/extensions/date_extensions.dart';

/// Controls gating for the Daily Opening Ritual (ReflectionScreen)
/// and Pause & Reflect v2 (auto-open and skipped-date registry).
///
/// Rules:
/// 1. Daily Opening Ritual is shown at most once per calendar day.
/// 2. Pause & Reflect auto-opens at most once per calendar day (when morningAfter state).
/// 3. Skipped prompt cards are tracked per calendar date so dismissing via "Skip" persists.
class ReflectionGateService {
  static const _kShownDateKey = 'reflection_gate_shown_date';
  static const _kAutoOpenOfferedDateKey = 'pause_reflect_auto_open_offered_date';
  static const _kSkippedDatesKey = 'pause_reflect_skipped_dates';

  // ---------------------------------------------------------------------------
  // Daily Opening Ritual (ReflectionScreen)
  // ---------------------------------------------------------------------------

  /// Returns true if the ReflectionScreen should be shown right now.
  static Future<bool> shouldShowReflection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getString(_kShownDateKey);
      return lastShown != DateTime.now().dateKey;
    } catch (_) {
      return false;
    }
  }

  /// Mark the ReflectionScreen as shown for today.
  static Future<void> markShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kShownDateKey, DateTime.now().dateKey);
    } catch (_) {
      // Worst case the ritual shows again on the next open.
    }
  }

  // ---------------------------------------------------------------------------
  // Pause & Reflect v2: Auto-Open Gate
  // ---------------------------------------------------------------------------

  /// Returns true if the Pause & Reflect sheet has already been auto-opened today.
  static Future<bool> hasAutoOpenBeenOfferedToday(DateTime today) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastOffered = prefs.getString(_kAutoOpenOfferedDateKey);
      return lastOffered == today.dateKey;
    } catch (_) {
      return false;
    }
  }

  /// Mark the Pause & Reflect sheet as auto-opened for [today].
  static Future<void> markAutoOpenOffered(DateTime today) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAutoOpenOfferedDateKey, today.dateKey);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Pause & Reflect v2: Skipped Dates
  // ---------------------------------------------------------------------------

  /// Returns true if the user explicitly skipped reflection for [date].
  static Future<bool> isDateSkipped(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skippedList = prefs.getStringList(_kSkippedDatesKey) ?? [];
      return skippedList.contains(date.dateKey);
    } catch (_) {
      return false;
    }
  }

  /// Mark [date] as skipped by the user via the prompt card.
  static Future<void> markDateSkipped(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skippedList =
          (prefs.getStringList(_kSkippedDatesKey) ?? []).toSet();
      skippedList.add(date.dateKey);
      await prefs.setStringList(_kSkippedDatesKey, skippedList.toList());
    } catch (_) {}
  }

  /// Clear the skipped status for [date] (e.g. if the user subsequently logs it).
  static Future<void> clearDateSkipped(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skippedList =
          (prefs.getStringList(_kSkippedDatesKey) ?? []).toSet();
      if (skippedList.remove(date.dateKey)) {
        await prefs.setStringList(_kSkippedDatesKey, skippedList.toList());
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Legacy / Test Compatibility Helpers
  // ---------------------------------------------------------------------------

  /// Backward-compatible alias for checking if auto-open is available today.
  static Future<bool> shouldShowPauseAndReflect() async {
    return !(await hasAutoOpenBeenOfferedToday(DateTime.now()));
  }

  /// Backward-compatible alias for marking auto-open offered for today.
  static Future<void> markPauseAndReflectShown() async {
    await markAutoOpenOffered(DateTime.now());
  }
}
