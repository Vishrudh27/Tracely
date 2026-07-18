import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/greeting_utils.dart';

/// Subtle motivational footer at the bottom of the Dashboard scroll.
///
/// One-liner that rotates daily. Styled in textDisabled — ethereal, breathing.
/// Intentionally not a card — floating text with generous breathing room.
class DashboardMotivationFooter extends StatelessWidget {
  const DashboardMotivationFooter({
    super.key,
    required this.opacity,
  });

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final quote = GreetingUtils.motivationFooter(AppStrings.motivationFooter);

    return Opacity(
      opacity: opacity * 0.65, // max 65% opacity — stays ethereal
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.massive,
          vertical: AppSpacing.massive,
        ),
        child: Text(
          quote,
          textAlign: TextAlign.center,
          style: context.textTheme.bodySmall?.copyWith(
            color: AppColors.textDisabled,
            fontStyle: FontStyle.italic,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
