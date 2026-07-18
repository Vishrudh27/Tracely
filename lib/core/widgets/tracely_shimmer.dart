import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// Shimmer loading placeholder widget.
///
/// Used instead of spinners/progress indicators when content is loading.
/// Shimmer placeholders match the shape of the content they replace,
/// so the layout doesn't jump when content loads.
///
/// Usage:
/// ```dart
/// TracelyShimmer(width: double.infinity, height: 72, radius: AppRadius.lg)
/// ```
class TracelyShimmer extends StatefulWidget {
  const TracelyShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<TracelyShimmer> createState() => _TracelyShimmerState();
}

class _TracelyShimmerState extends State<TracelyShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.shimmer,
    )..repeat(reverse: false);

    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.shimmer),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius:
                widget.borderRadius ?? const BorderRadius.all(Radius.circular(AppRadius.md)),
            gradient: LinearGradient(
              begin: Alignment(_shimmerAnimation.value - 1, 0),
              end: Alignment(_shimmerAnimation.value + 1, 0),
              colors: [
                AppColors.surfaceVariant,
                AppColors.border,
                AppColors.surfaceVariant,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// A shimmer placeholder shaped like a text line.
class TracelyShimmerLine extends StatelessWidget {
  const TracelyShimmerLine({
    super.key,
    this.width,
    this.height = 14,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TracelyShimmer(
      width: width ?? double.infinity,
      height: height,
      borderRadius: AppRadius.small,
    );
  }
}
