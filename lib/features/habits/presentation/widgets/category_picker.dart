import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/database/app_database.dart';

/// Grid of category cards for the Add/Edit Habit form.
///
/// Each card shows the category emoji + name.
/// Selected state: primary border + faint background tint.
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final cat = categories[i];
        final isSelected = selected?.id == cat.id;
        final color = Color(cat.colorValue);

        return GestureDetector(
          onTap: () => onSelected(cat),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.10) : AppColors.surface,
              borderRadius: AppRadius.card,
              border: Border.all(
                color: isSelected ? color : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  cat.name,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: isSelected ? color : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
