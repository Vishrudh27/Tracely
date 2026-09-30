import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/models/habit_models.dart';

/// Hero streak card for the Statistics screen — matches `statistics/code.html`:
/// one big current-streak number, a hairline divider, then a Best/Total grid.
///
/// "Best" is the longest streak ever recorded; "Total" is lifetime
/// completions across every habit. The number counts up on entrance.
class StreakDisplayCard extends StatelessWidget {
  const StreakDisplayCard({
    super.key,
    required this.streak,
    required this.totalCompletions,
    required this.opacity,
    required this.translateY,
    required this.countProgress, // 0.0–1.0 drives count-up animation
  });

  final StreakData streak;
  final int totalCompletions;
  final double opacity;
  final double translateY;
  final double countProgress;

  @override
  Widget build(BuildContext context) {
    final currentDisplay = (streak.currentStreak * countProgress).round();

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              children: [
                Text(
                  '$currentDisplay',
                  style: context.textTheme.displayLarge?.copyWith(
                    fontSize: AppSizes.streakNumberSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'day streak',
                  style: context.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w400, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _StatColumn(label: 'Best', value: streak.longestStreak),
                    ),
                    Expanded(
                      child: _StatColumn(label: 'Total', value: totalCompletions),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: context.textTheme.bodySmall),
        Text('$value', style: context.textTheme.titleMedium),
      ],
    );
  }
}
