import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';

class AnimatedQuoteCard extends StatelessWidget {
  const AnimatedQuoteCard({super.key, required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final opacity = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
    );

    final slide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.45, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    final glow = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.55, 0.90, curve: Curves.easeOut),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Align(
          alignment: const Alignment(0, 0.15),
          child: Transform.translate(
            offset: Offset(0, slide.value),
            child: Opacity(
              opacity: opacity.value,
              child: Padding(
                padding: AppSpacing.screen,
                child: Container(
                  width: double.infinity,
                  padding: AppSpacing.card,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.card,
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      ...AppShadows.md,
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08 * glow.value),
                        blurRadius: 40 * glow.value,
                        spreadRadius: 2 * glow.value,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        color: AppColors.primary,
                        size: AppSizes.iconLg,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      Text(
                        '"Small disciplines repeated\nwith consistency lead to\nremarkable achievements."',
                        textAlign: TextAlign.center,
                        style: AppTypography.textTheme.titleLarge?.copyWith(
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      Text(
                        "— John C. Maxwell",
                        style: AppTypography.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
