import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import 'reflection_taxonomy.dart';

/// Pinned strip in Zone 1 displaying the selected reflection reasons ("stones").
class StonesStrip extends StatelessWidget {
  const StonesStrip({
    super.key,
    required this.selectedKeys,
    required this.onRemove,
  });

  final List<String> selectedKeys;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final count = selectedKeys.length;

    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.stonesStripMinHeight),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border, width: AppSizes.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your stones',
                style: context.textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$count of 2',
                style: context.textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: AppDurations.fast,
            switchInCurve: AppCurves.easeOut,
            switchOutCurve: AppCurves.easeOut,
            child: count == 0
                ? Align(
                    key: const ValueKey('empty_stones'),
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Text(
                        'Choose up to two',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
                  )
                : Wrap(
                    key: ValueKey('stones_${selectedKeys.join('_')}'),
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final key in selectedKeys)
                        _MiniPebble(
                          key: ValueKey(key),
                          label: findReasonLabel(key),
                          onTap: () => onRemove(key),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MiniPebble extends StatelessWidget {
  const _MiniPebble({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.chip,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: AppRadius.chip,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.close,
                size: AppSizes.iconXs,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
