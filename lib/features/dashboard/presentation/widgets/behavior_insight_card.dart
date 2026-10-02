import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/behavior_insights.dart';

/// One quiet, dismissible suggestion drawn from the user's own patterns.
/// Same look as Statistics' WeeklyInsightsCard.
class BehaviorInsightCard extends StatelessWidget {
  const BehaviorInsightCard({
    super.key,
    required this.insight,
    required this.opacity,
    required this.translateY,
    required this.onDismiss,
    required this.onAction,
  });

  final BehaviorInsight insight;
  final double opacity;
  final double translateY;
  final VoidCallback onDismiss;

  /// Moves the habit's reminder to [BehaviorInsight.suggestedMinute].
  final VoidCallback onAction;

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
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: ColoredBox(color: AppColors.accentTerracotta),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg + 3,
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: AppColors.accentText,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              AppStrings.smartSuggestionTitle,
                              style: context.textTheme.titleSmall
                                  ?.copyWith(color: AppColors.accentText),
                            ),
                          ),
                          IconButton(
                            tooltip: AppStrings.insightDismiss,
                            onPressed: onDismiss,
                            icon: Icon(
                              Icons.close_rounded,
                              size: AppSizes.iconMd,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.md),
                        child: Text(
                          insight.message,
                          style: context.textTheme.bodyMedium,
                        ),
                      ),
                      if (insight.suggestedMinute != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: TextButton(
                            onPressed: onAction,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text(AppStrings.insightMoveReminder),
                          ),
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
