import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_accent_presets.dart';
import '../../app/theme/app_colors.dart';

/// Persists Settings' accent-color choice and keeps [AppColors.primary] in
/// sync. Mirrors [MotionService]'s shape.
class AccentColorService {
  AccentColorService._();

  static const _kAccentColorKey = 'accent_color_id';

  static Future<String> loadPresetId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccentColorKey) ?? kDefaultAccentPreset.id;
  }

  /// Applies a preset immediately (sync, no disk write) — for live preview
  /// while the Settings slider is still being dragged.
  static void applyPreview(String id) {
    AppColors.accentBase = presetById(id).base;
  }

  /// Writes the choice to disk. Does its own [applyPreview] first so a
  /// direct tap (no preceding drag) still re-skins the app.
  static Future<void> persist(String id) async {
    applyPreview(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccentColorKey, id);
  }

  static AccentPreset presetById(String id) => kAccentPresets.firstWhere(
        (p) => p.id == id,
        orElse: () => kDefaultAccentPreset,
      );
}
