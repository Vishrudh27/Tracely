import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../extensions/context_extensions.dart';

/// Reusable empty-state widget with warm, encouraging copy.
///
/// Never shows "No data" or "Nothing here" — always uses positive,
/// inviting language. Always provide an [icon], [title], and [body].
/// [ctaLabel] + [onCta] are optional — only show a CTA when there's
/// a clear, helpful next action.
class TracelyEmptyState extends StatelessWidget {
  const TracelyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: AppSizes.avatarXl,
              height: AppSizes.avatarXl,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: AppSizes.iconXl,
                color: AppColors.textDisabled,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Body
            Text(
              body,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),

            // Optional CTA
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: onCta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.button,
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    ctaLabel!,
                    style: context.textTheme.labelLarge?.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
