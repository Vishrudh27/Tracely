import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/database/app_database.dart';

/// Wrapped row of category chips for the Add/Edit Habit form.
///
/// Each chip: category dot + name. Selected state rings and colors the
/// chip in the category's own color, matching `add_habit/code.html`.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<Category> categories;
  final Category? selected;
  final ValueChanged<Category> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: categories.map((cat) {
        final isSelected = selected?.id == cat.id;
        final color = Color(cat.colorValue);

        return GestureDetector(
          onTap: () => onSelected(cat),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            height: AppSizes.chipHeight,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.surface : AppColors.surfaceVariant,
              borderRadius: AppRadius.small,
              border: isSelected ? Border.all(color: color, width: 2) : null,
              boxShadow: isSelected ? AppShadows.sm : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppSizes.categoryDot,
                  height: AppSizes.categoryDot,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  cat.name,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: isSelected ? color : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
