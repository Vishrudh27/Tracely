import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';

/// The 3-dot step indicator shared by every onboarding page.
///
/// The active dot widens into a pill rather than just changing color, so
/// progress reads clearly even for color-blind users.
class OnboardingProgressDots extends StatelessWidget {
  const OnboardingProgressDots({
    super.key,
    required this.pageCount,
    required this.activeIndex,
  });

  final int pageCount;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Onboarding progress',
      value: 'Step ${activeIndex + 1} of $pageCount',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(pageCount, (index) {
          final isActive = index == activeIndex;
          return AnimatedContainer(
            duration: AppDurations.medium,
            curve: AppCurves.standard,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            width: isActive ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.border,
              borderRadius: AppRadius.small,
            ),
          );
        }),
      ),
    );
  }
}
