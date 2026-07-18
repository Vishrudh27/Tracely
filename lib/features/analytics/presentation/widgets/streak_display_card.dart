import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/models/habit_models.dart';

/// Streak display card for the Statistics screen.
///
/// Shows current streak and longest streak side by side.
/// Streak numbers animate by counting up from 0 on entrance.
/// Shows a "Personal best!" badge if current ≥ longest.
/// Zero streak shows encouraging copy (no punishment).
class StreakDisplayCard extends StatelessWidget {
  const StreakDisplayCard({
    super.key,
    required this.streak,
    required this.opacity,
    required this.translateY,
    required this.countProgress, // 0.0–1.0 drives count-up animation
  });

  final StreakData streak;
  final double opacity;
  final double translateY;
  final double countProgress;

  @override
  Widget build(BuildContext context) {
    final currentDisplay =
        (streak.currentStreak * countProgress).round();
    final longestDisplay =
        (streak.longestStreak * countProgress).round();

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Container(
            padding: AppSpacing.card,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Current streak
                    Expanded(
                      child: _StreakColumn(
                        value: currentDisplay,
                        label: 'Current Streak',
                        emoji: streak.currentStreak == 0 ? '🌱' : '🔥',
                        color: AppColors.streakActive,
                        isPrimary: true,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: AppColors.border,
                    ),
                    // Longest streak
                    Expanded(
                      child: _StreakColumn(
                        value: longestDisplay,
                        label: 'Longest Streak',
                        emoji: '🏆',
                        color: AppColors.streakRecord,
                        isPrimary: false,
                      ),
                    ),
                  ],
                ),

                // Encouraging copy / personal best badge
                const SizedBox(height: AppSpacing.md),
                if (streak.isPersonalBest && streak.currentStreak > 0)
                  _PersonalBestBadge()
                else if (streak.currentStreak == 0)
                  Text(
                    'Start a new streak today 🌱',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Text(
                    '${streak.currentStreak} day${streak.currentStreak == 1 ? '' : 's'} and counting — keep going.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakColumn extends StatelessWidget {
  const _StreakColumn({
    required this.value,
    required this.label,
    required this.emoji,
    required this.color,
    required this.isPrimary,
  });

  final int value;
  final String label;
  final String emoji;
  final Color color;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          emoji,
          style: TextStyle(fontSize: isPrimary ? 24 : 20),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '$value',
          style: isPrimary
              ? context.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.0,
                )
              : context.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.75),
                  height: 1.0,
                ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PersonalBestBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.12),
        borderRadius: AppRadius.chip,
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨', style: TextStyle(fontSize: 12)),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            'Personal best!',
            style: context.textTheme.labelSmall?.copyWith(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
