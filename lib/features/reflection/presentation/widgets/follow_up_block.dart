import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import 'reflection_taxonomy.dart';

/// Follow-up block embedded directly within the triggering reason category card.
class FollowUpBlock extends StatelessWidget {
  const FollowUpBlock({
    super.key,
    required this.followUp,
    required this.selectedAnswer,
    required this.onAnswerChanged,
  });

  final FollowUpQuestion followUp;
  final String? selectedAnswer;
  final ValueChanged<String?> onAnswerChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Divider(
            height: AppSizes.divider,
            thickness: AppSizes.divider,
            color: AppColors.border,
          ),
        ),
        Text(
          followUp.question,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildOptions(context),
      ],
    );
  }

  Widget _buildOptions(BuildContext context) {
    final options = followUp.options;

    if (options.length <= 3) {
      return Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _FollowUpSegment(
                label: options[i],
                isSelected: selectedAnswer == options[i],
                onTap: () {
                  final newAnswer =
                      selectedAnswer == options[i] ? null : options[i];
                  onAnswerChanged(newAnswer);
                },
              ),
            ),
          ],
        ],
      );
    }

    // 4 options: 2x2 grid
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _FollowUpSegment(
                label: options[0],
                isSelected: selectedAnswer == options[0],
                onTap: () => onAnswerChanged(
                  selectedAnswer == options[0] ? null : options[0],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _FollowUpSegment(
                label: options[1],
                isSelected: selectedAnswer == options[1],
                onTap: () => onAnswerChanged(
                  selectedAnswer == options[1] ? null : options[1],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _FollowUpSegment(
                label: options[2],
                isSelected: selectedAnswer == options[2],
                onTap: () => onAnswerChanged(
                  selectedAnswer == options[2] ? null : options[2],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _FollowUpSegment(
                label: options[3],
                isSelected: selectedAnswer == options[3],
                onTap: () => onAnswerChanged(
                  selectedAnswer == options[3] ? null : options[3],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FollowUpSegment extends StatelessWidget {
  const _FollowUpSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadius.chip,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.easeOut,
          height: AppSizes.segmentHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: AppRadius.chip,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : AppSizes.divider,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
