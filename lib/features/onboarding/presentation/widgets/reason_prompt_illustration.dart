import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';

/// Onboarding page 2's illustration: an abstract mock of the Pause & Reflect
/// sheet — a prompt line above a row of reason chips, one shown selected.
/// Deliberately abstract (bars stand in for text) to match the sketch-like
/// tone of the rest of the onboarding art rather than mocking real copy.
class ReasonPromptIllustration extends StatelessWidget {
  const ReasonPromptIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Container(
          width: 236,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Bar(width: 28, height: 3, color: AppColors.primary, radius: 2),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: _Bar(width: 108, height: 3, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: _Bar(width: 64, height: 2, color: AppColors.border),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: const [
                  _MockChip(
                    pillWidth: 76,
                    lineWidth: 34,
                    color: AppColors.accentTerracotta,
                    emphasized: true,
                  ),
                  _MockChip(pillWidth: 78, lineWidth: 38, color: AppColors.primary),
                  _MockChip(pillWidth: 86, lineWidth: 46, color: AppColors.primary),
                  _MockChip(
                    pillWidth: 66,
                    lineWidth: 30,
                    color: AppColors.textDisabled,
                    hollow: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 1,
  });

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _MockChip extends StatelessWidget {
  const _MockChip({
    required this.pillWidth,
    required this.lineWidth,
    required this.color,
    this.emphasized = false,
    this.hollow = false,
  });

  final double pillWidth;
  final double lineWidth;
  final Color color;
  final bool emphasized;
  final bool hollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: pillWidth,
      height: AppSizes.chipHeight * 0.78,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.surfaceVariant : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color, width: emphasized ? 2 : 1.5),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hollow) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          _Bar(width: lineWidth, height: 2, color: color),
        ],
      ),
    );
  }
}
