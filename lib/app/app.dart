import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/accent_color_repository.dart';
import '../data/repositories/theme_mode_repository.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class TracelyApp extends ConsumerWidget {
  const TracelyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AppColors' brand tokens are mutable statics, not Theme.of(context)
    // lookups — watching these just to rebuild this widget (and thus
    // re-read AppTheme.current) whenever Settings changes the accent color
    // or dark mode. The actual repaint of everything else below this point
    // goes through forceFullRepaint, called from both notifiers — see its
    // doc for why a plain provider rebuild isn't enough on its own.
    ref.watch(accentColorProvider);
    ref.watch(darkModeProvider);

    // No AppBar anywhere in this app, so nothing else sets the status bar
    // icon color — without this, the clock/battery icons stay dark-on-dark
    // in dark mode.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,

        title: 'Tracely',

        theme: AppTheme.current,
        // Material widgets (dialogs, switches, the time picker) tween their
        // own colors over Flutter's default 200ms theme-change animation;
        // everything else here repaints instantly via forceFullRepaint, and
        // the mismatch between an animating dialog and a snapping divider
        // was visibly janky.
        themeAnimationDuration: Duration.zero,

        routerConfig: AppRouter.router,
      ),
    );
  }
}
