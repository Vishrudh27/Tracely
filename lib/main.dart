import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/theme/app_colors.dart';
import 'app/theme/app_durations.dart';
import 'data/services/accent_color_service.dart';
import 'data/services/motion_service.dart';
import 'data/services/theme_mode_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read once before the first frame so nothing animates at full speed and
  // then jumps to zero a beat later.
  AppDurations.reduceMotion = await MotionService.isEnabled();

  // Same reasoning — set AppColors.accentBase before the first frame so the
  // app doesn't flash the default brown before jumping to the saved accent.
  final presetId = await AccentColorService.loadPresetId();
  AppColors.accentBase = AccentColorService.presetById(presetId).base;

  // And the dark-mode flag, for the same reason — no light-mode flash
  // before jumping to a saved dark preference.
  AppColors.isDark = await ThemeModeService.isDarkEnabled();

  runApp(const ProviderScope(child: TracelyApp()));
}
