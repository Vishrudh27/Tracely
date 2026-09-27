import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_durations.dart';

/// Persists Settings' Reduce Motion toggle and keeps [AppDurations] in sync.
class MotionService {
  MotionService._();

  static const _kReduceMotionKey = 'reduce_motion';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kReduceMotionKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReduceMotionKey, enabled);
    AppDurations.reduceMotion = enabled;
  }
}
