import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';

/// An individual selectable reason button in the 2-column pebble grid.
class ReasonPebble extends StatelessWidget {
  const ReasonPebble({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
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
            height: AppSizes.pebbleHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surface,
              borderRadius: AppRadius.chip,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : AppSizes.divider,
              ),
              boxShadow: isSelected ? AppShadows.sm : const [],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: context.textTheme.bodyMedium?.copyWith(
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
