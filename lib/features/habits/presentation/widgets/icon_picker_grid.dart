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
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: AppIconRegistry.pickerOptions.map((key) {
        final isSelected = selected == key;

        return GestureDetector(
          onTap: () => onSelected(key),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.10)
                  : AppColors.surface,
              borderRadius: AppRadius.card,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Icon(
              AppIconRegistry.resolve(key),
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        );
      }).toList(),
    );
  }
}
