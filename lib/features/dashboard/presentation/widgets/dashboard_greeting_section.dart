import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/greeting_utils.dart';

/// Dashboard greeting section.
///
/// Shows a time-based greeting and today's date.
/// Does NOT use an AnimationController — it's driven by the parent
/// DashboardScreen's controller via [opacity] and [translateY].
class DashboardGreetingSection extends StatelessWidget {
  const DashboardGreetingSection({
    super.key,
    required this.opacity,
    required this.translateY,
    this.currentStreak = 0,
  });

  final double opacity;
  final double translateY;
  final int currentStreak;

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
                GreetingUtils.greeting(),
                style: context.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                DateFormat('EEEE, d MMMM').format(DateTime.now()),
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
