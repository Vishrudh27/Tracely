import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Standard Tracely card widget.
///
/// Enforces consistent radius, shadow, background, and padding
/// across all cards in the app. Never use a raw [Container] with
/// decoration for a card — always use this widget.
class TracelyCard extends StatelessWidget {
  const TracelyCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.shadows,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: borderColor ?? AppColors.border,
        ),
        boxShadow: shadows ?? AppShadows.sm,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.card,
            splashColor: AppColors.primary.withValues(alpha: 0.06),
            highlightColor: AppColors.primary.withValues(alpha: 0.04),
            child: Padding(
              padding: padding ?? AppSpacing.card,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
