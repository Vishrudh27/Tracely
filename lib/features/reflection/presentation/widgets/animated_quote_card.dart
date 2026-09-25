import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/quote_constants.dart';

/// Animated quote card shown on the Daily Opening Ritual (ReflectionScreen).
///
/// Quote is selected deterministically by day-of-year via QuoteConstants.todaysQuote()
/// so the user sees a different quote each day, but the same quote all day long.
///
/// Entrance animation (within the 2000ms ReflectionScreen controller):
///   Opacity:  Interval(0.45, 0.75) — easeOut fade-in
///   Slide:    Interval(0.45, 0.80) — easeOutCubic, 40px → 0
///   Glow:     Interval(0.55, 0.90) — easeOut warm glow under card
class AnimatedQuoteCard extends StatelessWidget {
  const AnimatedQuoteCard({super.key, required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    // Select today's quote deterministically (same quote all day, new each day)
    final quote = QuoteConstants.todaysQuote();

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
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: [
                      ...AppShadows.sm,
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
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.format_quote_rounded,
                          color: AppColors.primary,
                          size: AppSizes.iconLg,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      Text(
                        quote.text,
                        textAlign: TextAlign.center,
                        style: AppTypography.textTheme.titleLarge?.copyWith(
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      Text(
                        quote.author,
                        style: AppTypography.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
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
