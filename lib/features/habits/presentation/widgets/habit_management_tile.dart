import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_icon_registry.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/habit_schedule.dart';
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

  @override
  Widget build(BuildContext context) {
    final color = category != null
        ? Color(category!.colorValue)
        : AppColors.categoryCustom;
    final iconKey = habit.emoji ?? category?.emoji;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      constraints: const BoxConstraints(minHeight: AppSizes.cardMinHeight),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
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
                        style: context.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        frequencyLabel(habit.frequencyType, habit.frequencyConfig),
                        style: context.textTheme.bodySmall,
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
