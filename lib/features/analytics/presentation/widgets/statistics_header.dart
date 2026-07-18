import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';

/// Statistics screen header.
///
/// "Your Journey" title + adaptive subtitle showing how long the user
/// has been using Tracely (derived from the first habit creation date).
class StatisticsHeader extends StatelessWidget {
  const StatisticsHeader({
    super.key,
    required this.opacity,
    required this.translateY,
    this.daysSinceStart = 0,
  });

  final double opacity;
  final double translateY;

  /// Days since the user first created a habit (0 if new).
  final int daysSinceStart;

  String get _subtitle {
    if (daysSinceStart <= 0) return 'Your consistency, beautifully captured.';
    final weeks = (daysSinceStart / 7).floor();
    final months = (daysSinceStart / 30).floor();
    if (months >= 2) return '$months months of building.';
    if (weeks >= 2) return '$weeks weeks of showing up.';
    if (daysSinceStart == 1) return 'Day 1 — the most important one.';
    return '$daysSinceStart days of building.';
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Journey',
                style: context.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _subtitle,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
