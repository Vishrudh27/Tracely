import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_colors.dart';

/// Persists Settings'/Dashboard's dark-mode toggle and keeps
/// [AppColors.isDark] in sync. Mirrors [MotionService]'s shape. Manual
/// toggle only — no follow-system option, matching every other Settings
/// switch in this app.
class ThemeModeService {
  ThemeModeService._();

  static const _kDarkModeKey = 'dark_mode';

  static Future<bool> isDarkEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDarkModeKey) ?? false;
  }

  static Future<void> setDarkEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkModeKey, enabled);
    AppColors.isDark = enabled;
  }
}
