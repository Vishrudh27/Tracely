import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/models/habit_models.dart';

/// Daily progress card showing a circular ring with today's completion.
///
/// Animated on screen entrance: ring fills from 0 to actual percentage.
/// Glows softly when all habits are done.
class DailyProgressCard extends StatelessWidget {
  const DailyProgressCard({
    super.key,
    required this.progress,
    required this.controller,
    required this.cardOpacity,
    required this.cardTranslateY,
  });

  final DailyProgress progress;
  final AnimationController controller;
  final double cardOpacity;
  final double cardTranslateY;

  String get _progressCopy {
    if (progress.isEmpty) return AppStrings.progressFreshStart;
    if (progress.allDone) return AppStrings.progressAllDone;
    if (progress.noneDone) return AppStrings.progressFreshStart;
    return AppStrings.progressKeepGoing;
  }

  @override
  Widget build(BuildContext context) {
    // Ring fill animates within the card's entrance window (roughly 0.10-0.55)
    final ringAnimation = Tween<double>(
      begin: 0,
      end: progress.percentage,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.20, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    return Opacity(
      opacity: cardOpacity,
      child: Transform.translate(
        offset: Offset(0, cardTranslateY),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Container(
            width: double.infinity,
            padding: AppSpacing.card,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm,
            ),
            child: Row(
              children: [
                // Circular progress ring
                AnimatedBuilder(
                  animation: ringAnimation,
                  builder: (context, child) {
                    return SizedBox(
                      width: AppSizes.progressRingSize,
                      height: AppSizes.progressRingSize,
                      child: CustomPaint(
                        painter: _ProgressRingPainter(
                          percentage: ringAnimation.value,
                          strokeWidth: AppSizes.progressRingStroke,
                          trackColor: AppColors.border,
                          progressColor: progress.allDone
                              ? AppColors.primaryLight
                              : AppColors.primary,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${progress.completedCount}',
                                style: context.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                'of ${progress.totalCount}',
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(width: AppSpacing.xl),

                // Progress text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _progressCopy,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      if (!progress.isEmpty && !progress.allDone) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${progress.remaining} left',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (progress.allDone) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'All done!',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the circular progress ring.
class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.percentage,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  final double percentage;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Track (full circle)
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc (from top, clockwise)
    if (percentage > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start at top
        2 * math.pi * percentage,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}
