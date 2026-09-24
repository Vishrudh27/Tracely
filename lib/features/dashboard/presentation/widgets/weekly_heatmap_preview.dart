import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/models/habit_models.dart';

/// Compact 7-day heatmap strip for the Dashboard.
///
/// Shows Mon–Sun cells colored by completion intensity.
/// Tapping the strip can navigate to full Statistics.
class WeeklyHeatmapPreview extends StatelessWidget {
  const WeeklyHeatmapPreview({
    super.key,
    required this.days,
    required this.opacity,
    required this.translateY,
    this.onTap,
  });

  final List<DayCompletion> days;
  final double opacity;
  final double translateY;
  final VoidCallback? onTap;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: AppSpacing.card,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.card,
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'This Week',
                        style: context.textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                        size: AppSizes.iconMd,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final dayData = i < days.length ? days[i] : null;
                      final level = dayData?.heatmapLevel ?? 0;
                      final isToday = dayData?.date.isToday ?? false;

                      return Column(
                        children: [
                          // Day label
                          Text(
                            _dayLabels[i],
                            style: context.textTheme.labelSmall?.copyWith(
                              color: isToday
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          // Heatmap cell
                          Container(
                            width: AppSizes.weeklyHeatmapCellSize,
                            height: AppSizes.weeklyHeatmapCellSize,
                            decoration: BoxDecoration(
                              color: AppColors.heatmap[level],
                              borderRadius: AppRadius.small,
                              border: isToday
                                  ? Border.all(
                                      color: AppColors.primary,
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extension on DateTime — isToday (local, for heatmap cells).
extension _DateTodayCheck on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}
