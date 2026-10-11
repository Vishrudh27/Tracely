import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';

/// Free-text card at the bottom of the reflection sheet for custom thoughts.
class MyReasonCard extends StatelessWidget {
  const MyReasonCard({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: AppColors.border,
          width: AppSizes.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note,
                size: AppSizes.iconSm,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'MY REASON',
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            onChanged: onChanged,
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              hintText: 'Something else on your mind...',
              hintStyle: context.textTheme.bodyMedium?.copyWith(
                color: AppColors.textDisabled,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: BorderSide(
                  color: AppColors.border,
                  width: AppSizes.divider,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: BorderSide(
                  color: AppColors.border,
                  width: AppSizes.divider,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
