import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/greeting_utils.dart';

/// Dashboard greeting section.
///
/// Shows a time-based greeting and today's date.
/// Does NOT use an AnimationController — it's driven by the parent
/// DashboardScreen's controller via [opacity] and [translateY].
class DashboardGreetingSection extends StatelessWidget {
  const DashboardGreetingSection({
    super.key,
    required this.opacity,
    required this.translateY,
    this.currentStreak = 0,
    this.allDone = false,
    this.onSettingsTap,
    this.isDark = false,
    this.onToggleTheme,
  });

  final double opacity;
  final double translateY;
  final int currentStreak;

  /// Everything today is done — Stitch shows a settled "Day complete."
  final bool allDone;

  /// Not in Stitch's mock — Settings lost its only entry point (a shared
  /// header none of the rebuilt screens kept) once every tab was rebuilt
  /// exact. Shown only when provided, so this stays a no-op deviation until
  /// wired from the screen.
  final VoidCallback? onSettingsTap;

  /// Also not in Stitch — Settings' dark-mode switch needed a
  /// no-navigation, one-tap twin here. Same "shown only when provided"
  /// contract as [onSettingsTap], so tests that don't wire it stay simple.
  final bool isDark;
  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      GreetingUtils.greeting(),
                      style: context.textTheme.displaySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      allDone
                          ? 'Day complete.'
                          : GreetingUtils.dashboardSubtitle(
                              currentStreak: currentStreak),
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onToggleTheme != null)
                IconButton(
                  onPressed: onToggleTheme,
                  icon: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  ),
                  iconSize: AppSizes.iconLg,
                  color: AppColors.textSecondary,
                  tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                ),
              if (onSettingsTap != null)
                IconButton(
                  onPressed: onSettingsTap,
                  icon: const Icon(Icons.settings_outlined),
                  iconSize: AppSizes.iconLg,
                  color: AppColors.textSecondary,
                  tooltip: 'Settings',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
