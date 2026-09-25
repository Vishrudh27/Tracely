import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';

/// Quiet reflection line shown at the bottom of the Add/Edit Habit form.
class HabitFormTipCard extends StatelessWidget {
  const HabitFormTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.spa_outlined,
            size: 20,
            color: AppColors.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Habits bloom gently. Small, conscious pauses matter more '
              'than unbroken tallies.',
              style: context.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
