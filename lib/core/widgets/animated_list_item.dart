import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Wraps a list item with a staggered fade+slide entrance animation.
///
/// Used when building lists on Dashboard (habit tiles) and other screens
/// to create the smooth staggered entry effect. Each item fades in and
/// slides up from a small offset based on its [index].
///
/// The parent screen passes its [AnimationController] and this widget
/// computes its own Interval within the overall timeline based on [index]
/// and [totalItems].
///
/// Example:
/// ```dart
/// AnimatedListItem(
///   controller: _controller,
///   index: i,
///   totalItems: habits.length,
///   intervalStart: 0.30,
///   intervalEnd: 0.70,
///   child: HabitTile(habit: habit),
/// )
/// ```
class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    super.key,
    required this.controller,
    required this.index,
    required this.totalItems,
    required this.child,
    this.intervalStart = 0.0,
    this.intervalEnd = 1.0,
    this.slideOffsetY = 20.0,
  });

  final AnimationController controller;
  final int index;
  final int totalItems;
  final Widget child;

  /// The start of the window within the parent controller for ALL list items.
  final double intervalStart;

  /// The end of the window within the parent controller for ALL list items.
  final double intervalEnd;

  /// How many pixels the item slides up from (default: 20px).
  final double slideOffsetY;

  @override
  Widget build(BuildContext context) {
    // Distribute items across intervalStart..intervalEnd with 60% overlap.
    final itemWindow = (intervalEnd - intervalStart);
    final count = totalItems == 0 ? 1 : totalItems;
    final step = itemWindow / count;
    final start = (intervalStart + index * step * 0.6).clamp(0.0, 0.99);
    final end = (start + step * 1.5).clamp(start + 0.01, 1.0);

    final opacity = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: AppCurves.list),
    );

    final slide = Tween<double>(begin: slideOffsetY, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(start, end, curve: AppCurves.emphasizedDecelerate),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Opacity(
          opacity: opacity.value,
          child: Transform.translate(
            offset: Offset(0, slide.value),
            child: this.child, // Use this.child or child parameter
          ),
        );
      },
    );
  }
}
