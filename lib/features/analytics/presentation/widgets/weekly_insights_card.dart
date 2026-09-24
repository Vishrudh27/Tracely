import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/models/habit_models.dart';

/// Weekly insights card — a warm, positive 2–3 sentence observation.
///
/// Background uses AppColors.insightCard (warm cream) to visually
/// distinguish it from standard white cards. Text is italic for a
/// journal-letter feel.
class WeeklyInsightsCard extends StatelessWidget {
  const WeeklyInsightsCard({
    super.key,
    required this.insight,
    required this.opacity,
    required this.translateY,
  });

  final WeeklyInsight insight;
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
          child: Container(
            width: double.infinity,
            padding: AppSpacing.statisticsCard,
            decoration: BoxDecoration(
              color: AppColors.insightCard,
              borderRadius: AppRadius.card,
              border: Border.all(
                color: AppColors.primaryLight.withValues(alpha: 0.25),
              ),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'This Week',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  insight.message,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.65,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (insight.weeklyCompletionRate > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  _CompletionBar(rate: insight.weeklyCompletionRate),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletionBar extends StatelessWidget {
  const _CompletionBar({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weekly completion',
              style: context.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${(rate * 100).round()}%',
              style: context.textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rate.clamp(0.0, 1.0),
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
