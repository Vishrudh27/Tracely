import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';

class ReflectionBackground extends StatelessWidget {
  const ReflectionBackground({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final glowAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(color: AppColors.background),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 320 + (80 * glowAnimation.value),
                  height: 320 + (80 * glowAnimation.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryLight.withValues(
                          alpha: 0.20 * glowAnimation.value,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
