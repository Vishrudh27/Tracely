import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/force_repaint.dart';
import '../services/theme_mode_service.dart';

/// Holds the dark-mode toggle, delegating persistence to
/// [ThemeModeService]. Mirrors [ReduceMotionNotifier]'s shape.
class ThemeModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ThemeModeService.isDarkEnabled();

  Future<void> setEnabled(bool enabled) async {
    await ThemeModeService.setDarkEnabled(enabled);
    state = AsyncData(enabled);
    // ThemeModeService already flips AppColors.isDark; this is what makes
    // every already-built const widget actually repaint with it — see
    // forceFullRepaint's doc for why a plain provider rebuild isn't enough.
    forceFullRepaint();
  }
}

final darkModeProvider = AsyncNotifierProvider<ThemeModeNotifier, bool>(
  ThemeModeNotifier.new,
);
