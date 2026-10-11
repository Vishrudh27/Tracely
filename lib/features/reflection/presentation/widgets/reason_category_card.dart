import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import 'follow_up_block.dart';
import 'reason_pebble.dart';
import 'reflection_taxonomy.dart';

/// Category card presenting a category header, strict 2-column pebble grid,
/// and an optional inline follow-up question.
class ReasonCategoryCard extends StatelessWidget {
  const ReasonCategoryCard({
    super.key,
    required this.category,
    required this.selectedKeys,
    required this.onPebbleTapped,
    this.activeFollowUp,
    this.selectedFollowUpAnswer,
    this.onFollowUpAnswerChanged,
  });

  final ReasonCategory category;
  final List<String> selectedKeys;
  final ValueChanged<String> onPebbleTapped;
  final ResolvedFollowUp? activeFollowUp;
  final String? selectedFollowUpAnswer;
  final ValueChanged<String?>? onFollowUpAnswerChanged;

  @override
  Widget build(BuildContext context) {
    // Check if the currently active follow-up belongs to a reason in this category
    final hasActiveFollowUpHere = activeFollowUp != null &&
        category.reasons.any((r) => r.key == activeFollowUp!.triggerReasonKey);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: AppColors.border,
          width: AppSizes.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              Icon(
                category.icon,
                size: AppSizes.iconSm,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                category.label.toUpperCase(),
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Strict 2-column grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent: AppSizes.pebbleHeight,
            children: [
              for (final reason in category.reasons)
                ReasonPebble(
                  label: reason.label,
                  isSelected: selectedKeys.contains(reason.key),
                  onTap: () => onPebbleTapped(reason.key),
                ),
            ],
          ),

          // Inline Follow-up block when triggered by a reason in this category
          AnimatedSize(
            duration: AppDurations.medium,
            curve: AppCurves.easeOut,
            child: hasActiveFollowUpHere && onFollowUpAnswerChanged != null
                ? FollowUpBlock(
                    followUp: activeFollowUp!.followUp,
                    selectedAnswer: selectedFollowUpAnswer,
                    onAnswerChanged: onFollowUpAnswerChanged!,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
