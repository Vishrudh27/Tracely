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
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.insightCard,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.sm,
            ),
            child: Stack(
              children: [
                // Sole terracotta anchor for this viewport, per the design
                // system's "one accent per screen" rule.
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: ColoredBox(color: AppColors.accentTerracotta),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg + 3,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: AppColors.accentText,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'This week',
                            style: context.textTheme.titleSmall
                                ?.copyWith(color: AppColors.accentText),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        insight.message,
                        style: context.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
