import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';

/// The 3-dot step indicator shared by every onboarding page.
///
/// Stitch draws three equal 8px circles, the active one filled in coffee —
/// so colour is the only visual cue. The Semantics wrapper carries "Step N
/// of M" for anyone that cue doesn't reach.
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
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.border,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
