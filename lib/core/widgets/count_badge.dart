import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../extensions/context_extensions.dart';

/// The "done / total" pill in a section header — e.g. "3/5", or "5/5" in
/// success green once everything is finished.
///
/// Stitch draws this on the Dashboard's Today's Habits and Today's Tasks
/// headers (`dashboard_all_done_state`); shared so both read identically.
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.done,
    required this.total,
  });

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final complete = total > 0 && done >= total;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.fab,
      ),
      child: Text(
        '$done/$total',
        style: context.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: complete ? AppColors.success : AppColors.textSecondary,
        ),
      ),
    );
  }
}
