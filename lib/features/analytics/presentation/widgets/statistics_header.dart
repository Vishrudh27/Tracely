import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';

/// Fixed Statistics header — title only, no trailing action, matching
/// `statistics/code.html` (same bare h-16 pattern as the Habits header,
/// minus its filter icon).
class StatisticsHeader extends StatelessWidget {
  const StatisticsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.appBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      alignment: Alignment.centerLeft,
      child: Text('Statistics', style: context.textTheme.displaySmall),
    );
  }
}
