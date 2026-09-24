import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_icon_registry.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/database/app_database.dart';

/// Habit tile in the Habits management screen.
///
/// Shows: category dot, icon, habit name, frequency label, chevron.
/// Tapping navigates to the Edit screen.
class HabitManagementTile extends StatelessWidget {
  const HabitManagementTile({
    super.key,
    required this.habit,
    required this.onTap,
    this.category,
  });

  final Habit habit;
  final Category? category;
  final VoidCallback onTap;

  String get _frequencyLabel {
    switch (habit.frequencyType) {
      case 'daily':
        return 'Daily';
      case 'specific_days':
        return 'Specific days';
      case 'x_per_week':
        return 'Custom';
      default:
        return 'Daily';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = category != null
        ? Color(category!.colorValue)
        : AppColors.categoryCustom;
    final iconKey = habit.emoji ?? category?.emoji;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.card,
          onTap: onTap,
          splashColor: AppColors.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: AppSpacing.habitTile,
            child: Row(
              children: [
                // Category dot
                Container(
                  width: AppSizes.categoryDot,
                  height: AppSizes.categoryDot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Icon
                Icon(
                  AppIconRegistry.resolve(iconKey),
                  size: 20,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: AppSpacing.md),

                // Name + frequency
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        habit.name,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _frequencyLabel,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textDisabled,
                  size: AppSizes.iconMd,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
