import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';

/// Two pill-shaped quick-stat chips below the weekly heatmap: current
/// streak and this week's consistency.
class QuickStatsRow extends StatelessWidget {
  const QuickStatsRow({
    super.key,
    required this.currentStreak,
    required this.weeklyConsistency,
    required this.opacity,
    required this.translateY,
  });

  final int currentStreak;

  /// 0.0–1.0 average completion across the last 7 days.
  final double weeklyConsistency;
  final double opacity;
  final double translateY;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.local_fire_department_rounded,
                  label: currentStreak > 0
                      ? '$currentStreak Day Streak'
                      : 'New streak',
                  color: AppColors.primary,
                  background: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatChip(
                  icon: Icons.trending_up_rounded,
                  label:
                      '${(weeklyConsistency * 100).round()}% Consistency',
                  color: AppColors.textSecondary,
                  background: AppColors.surfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.fab,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: AppSizes.iconSm),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
