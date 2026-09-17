import 'package:shared_preferences/shared_preferences.dart';

/// Controls whether the Daily Opening Ritual (ReflectionScreen) should
/// be shown on the current app open.
///
/// Rules:
/// 1. Shown on the first app open of each calendar day, at any hour.
/// 2. Shown at most once per calendar day.
/// 3. Always skippable — the user is never blocked.
///
/// The gate used to also require `hour < 12`, which meant anyone whose first
/// open of the day fell after noon never saw the ritual — or the quote — at
/// all that day. The once-per-day rule alone gives the ritual its meaning.
///
/// Uses SharedPreferences for persistence so the gate check is fast
/// and doesn't require a database query at router init time.
class ReflectionGateService {
  static const _kShownDateKey = 'reflection_gate_shown_date';
  static const _kPauseReflectDateKey = 'pause_reflect_shown_date';

  /// Returns true if the ReflectionScreen should be shown right now.
  ///
  /// True when the ritual has not yet been shown on today's calendar date.
  /// Never throws — if preferences are unreadable the ritual is skipped
  /// rather than blocking startup.
  static Future<bool> shouldShowReflection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getString(_kShownDateKey);
      return lastShown != _dateKey(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// Mark the ReflectionScreen as shown for today.
  ///
  /// Call this as soon as the screen begins its entrance animation,
  /// not when Continue is pressed (to prevent re-showing on back nav).
  static Future<void> markShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kShownDateKey, _dateKey(DateTime.now()));
    } catch (_) {
      // Worst case the ritual shows again on the next open.
    }
  }

  /// Returns true if the Pause & Reflect sheet should be offered today.
  ///
  /// Tracked here rather than by looking for a reflection row, because
  /// dismissing the sheet with "Not now" writes no row — so a row-based gate
  /// let the sheet reappear on the next app open the same day.
  static Future<bool> shouldShowPauseAndReflect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getString(_kPauseReflectDateKey);
      return lastShown != _dateKey(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// Mark the Pause & Reflect sheet as offered for today.
  ///
  /// Call this when the sheet is presented, not when it is answered — being
  /// asked is what consumes the day's prompt.
  static Future<void> markPauseAndReflectShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPauseReflectDateKey, _dateKey(DateTime.now()));
    } catch (_) {
      // Worst case the sheet is offered again on the next open.
    }
  }

  /// Builds an ISO-like date string for today: "YYYY-MM-DD".
  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
