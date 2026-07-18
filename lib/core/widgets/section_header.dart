import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../extensions/context_extensions.dart';

/// Section header with title and optional trailing action.
///
/// Used consistently across Dashboard, Habits, and Statistics screens
/// to introduce each section. Never hardcode section headers inline.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding,
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
