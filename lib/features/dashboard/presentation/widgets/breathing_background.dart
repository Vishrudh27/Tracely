import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';

/// Ambient breathing background for the Dashboard (§6.6 — Consistency Pulse).
///
/// A very subtle radial gradient that slowly pulses its opacity between
/// 0.03 and 0.08 on a 6-second cycle. The gradient warmth adapts to
/// overall completion consistency.
///
/// This is the ONE exception to "no independent controllers per widget" —
/// the breathing background is an ambient loop, not an entrance animation.
class BreathingBackground extends StatefulWidget {
  const BreathingBackground({
    super.key,
    required this.weeklyCompletionRate,
  });

  /// 0.0–1.0 weekly completion rate (drives gradient color warmth).
  final double weeklyCompletionRate;

  @override
  State<BreathingBackground> createState() => _BreathingBackgroundState();
}

class _BreathingBackgroundState extends State<BreathingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  late final Animation<double> _breathAnim;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );

    _breathAnim = Tween<double>(begin: 0.03, end: 0.08).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // Infinite sinusoidal pulse
    _breathController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  /// Gradient color based on weekly consistency.
  Color get _glowColor {
    if (widget.weeklyCompletionRate > 0.8) {
      // High consistency — warm amber glow
      return AppColors.primaryLight;
    } else if (widget.weeklyCompletionRate > 0.4) {
      // Medium — standard primary
      return AppColors.primary;
    } else {
      // Low — very neutral, barely there
      return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathAnim,
      builder: (context, _) {
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [
                  _glowColor.withValues(alpha: _breathAnim.value),
                  AppColors.background.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}
