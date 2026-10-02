import 'package:shared_preferences/shared_preferences.dart';

/// Persists Settings' Smart suggestions toggle and which suggestion cards
/// the user has dismissed. Mirrors [MotionService]'s shape.
class InsightService {
  InsightService._();

  static const _kEnabledKey = 'smart_suggestions';
  static const _kDismissedKey = 'dismissed_insights';

  /// On by default — suggestions are quiet and dismissible.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabledKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, enabled);
  }

  static Future<Set<String>> loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return {...?prefs.getStringList(_kDismissedKey)};
  }

  static Future<void> dismiss(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = {...?prefs.getStringList(_kDismissedKey), key};
    await prefs.setStringList(_kDismissedKey, keys.toList());
  }

  /// Clear All Data means "back to first install".
  static Future<void> clearDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDismissedKey);
  }
}
