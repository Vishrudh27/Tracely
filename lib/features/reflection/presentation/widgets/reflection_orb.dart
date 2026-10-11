import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';

/// Interactive glowing orb reflecting user progress (0..1).
///
/// Features:
/// - RadialGradient interpolated from [AppColors.orbPale] to [AppColors.clay].
/// - Soft outer glow BoxShadow sized proportionally to [size].
/// - Smooth progress animation via [TweenAnimationBuilder] (no idle pulsing).
class ReflectionOrb extends StatelessWidget {
  const ReflectionOrb({
    super.key,
    required this.progress,
    this.size = AppSizes.orbSize,
  });

  /// Progress from 0.0 (no stones/reflections) to 1.0 (completed/2 stones).
  final double progress;

  /// Orb diameter (defaults to [AppSizes.orbSize] = 40).
  final double size;

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: clampedProgress),
      duration: AppDurations.medium,
      curve: AppCurves.easeOut,
      builder: (context, animValue, _) {
        final Color coreColor;
        final Color rimColor;

        if (AppColors.isDark) {
          // Dark mode: Radiant, luminous warm amber glow without any desaturated grey.
          if (animValue == 0.0) {
            coreColor = AppColors.orbPale;
          } else {
            // Lerps from rich golden amber to luminous radiant molten gold
            final activeCore = Color.lerp(
              const Color(0xFFE5A028),
              const Color(0xFFFFDF7E),
              animValue,
            )!;
            coreColor = Color.lerp(
              AppColors.orbPale,
              activeCore,
              (animValue * 2.0).clamp(0.0, 1.0),
            )!;
          }

          rimColor = Color.lerp(
            const Color(0xFF5E421E),
            AppColors.clay,
            animValue,
          )!;
        } else {
          // Light mode: Soft sunlight mist warming to golden amber.
          coreColor = Color.lerp(
            AppColors.orbPale,
            Color.lerp(AppColors.orbPale, const Color(0xFFFFF9EE), 0.60)!,
            animValue,
          )!;

          rimColor = Color.lerp(
            Color.lerp(AppColors.orbPale, AppColors.clay, 0.25)!,
            AppColors.clay,
            animValue,
          )!;
        }

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                coreColor,
                rimColor,
              ],
              stops: const [0.25, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.isDark
                    ? AppColors.clay.withValues(alpha: 0.12 + (0.36 * animValue))
                    : rimColor.withValues(alpha: 0.15 + (0.28 * animValue)),
                blurRadius: size *
                    (AppColors.isDark
                        ? (0.45 + (0.40 * animValue))
                        : (0.40 + (0.30 * animValue))),
                spreadRadius: 0,
              ),
            ],
          ),
        );
      },
    );
  }
}
