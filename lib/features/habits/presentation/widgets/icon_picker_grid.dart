import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_icon_registry.dart';

/// Wrapped grid of Material icons for habit customization.
///
/// Replaces the old emoji picker — same interaction (tap to select, subtle
/// highlight on the chosen one), but every option is a recolorable vector
/// icon from [AppIconRegistry] instead of an OS-rendered emoji glyph.
class IconPickerGrid extends StatelessWidget {
  const IconPickerGrid({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = AppIconRegistry.pickerOptions;

    // Horizontal scroll row, matching Stitch's `overflow-x-auto` icon
    // strip — the app's full icon set is far larger than Stitch's 6-tile
    // sample, so a single scrollable row (not a multi-row Wrap) keeps
    // Category/Frequency from being pushed down the screen.
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (context, i) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final key = options[i];
          final isSelected = selected == key;

          return GestureDetector(
            onTap: () => onSelected(key),
            child: AnimatedContainer(
              duration: AppDurations.fast,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.surface : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
                boxShadow: isSelected ? AppShadows.sm : null,
              ),
              child: Icon(
                AppIconRegistry.resolve(key),
                size: 22,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }
}
