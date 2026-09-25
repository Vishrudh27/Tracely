import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/utils/greeting_utils.dart';

class AnimatedGreeting extends StatelessWidget {
  const AnimatedGreeting({super.key, required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final fadeAnimation = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );

    final moveAnimation = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.20, 0.55, curve: Curves.easeInOutCubic),
    );

    final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Align(
          alignment: Alignment(
            0,
            Tween<double>(begin: 0.0, end: -0.82).evaluate(moveAnimation),
          ),
          child: Opacity(
            opacity: fadeAnimation.value,
            child: Transform.scale(
              scale: scaleAnimation.value,
              child: Padding(
                padding: AppSpacing.screen,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      GreetingUtils.greeting(),
                      textAlign: TextAlign.center,
                      style: AppTypography.textTheme.displayMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xs),

                    Text(
                      DateFormat('EEEE, d MMMM').format(DateTime.now()),
                      textAlign: TextAlign.center,
                      style: AppTypography.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
