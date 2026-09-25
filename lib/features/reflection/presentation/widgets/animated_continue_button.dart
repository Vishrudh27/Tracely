import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';

class AnimatedContinueButton extends StatelessWidget {
  const AnimatedContinueButton({super.key, required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final opacity = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.80, 1.0, curve: Curves.easeOut),
    );

    final slide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.80, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, slide.value),
            child: Opacity(
              opacity: opacity.value,
              child: Padding(
                padding: AppSpacing.screen,
                child: SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.go(AppRouter.dashboard);
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    iconAlignment: IconAlignment.end,
                    label: Text(
                      'Continue',
                      style: AppTypography.textTheme.titleMedium
                          ?.copyWith(color: AppColors.textOnPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.button,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
