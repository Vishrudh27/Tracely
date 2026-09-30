import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';

/// Onboarding page 1's illustration: seven connected days, two of them
/// hollow — the "gap" a normal tracker leaves unexplained — bracketed by a
/// single terracotta question mark. This is the visual thesis of the app,
/// so it earns a hand-drawn CustomPainter rather than a generic widget.
class StreakGapIllustration extends StatelessWidget {
  const StreakGapIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 180,
      child: CustomPaint(
        painter: _StreakGapPainter(),
        child: const Center(),
      ),
    );
  }
}

class _StreakGapPainter extends CustomPainter {
  // Days that render hollow — the "missed, unexplained" gap.
  static const _gapIndices = {3, 4};
  static const _dayCount = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final left = size.width * (26 / 280);
    final right = size.width * (260 / 280);
    final centerY = size.height * (80 / 180);
    final filledRadius = size.width * (13 / 280);
    final hollowRadius = size.width * (12 / 280);
    final step = (right - left) / (_dayCount - 1);

    final centers = List.generate(
      _dayCount,
      (i) => Offset(left + step * i, centerY),
    );

    _drawDashedLine(
      canvas,
      Offset(left, centerY),
      Offset(right, centerY),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 2,
    );

    for (var i = 0; i < _dayCount; i++) {
      final center = centers[i];
      if (_gapIndices.contains(i)) {
        canvas.drawCircle(
          center,
          hollowRadius,
          Paint()..color = AppColors.background,
        );
        canvas.drawCircle(
          center,
          hollowRadius,
          Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawCircle(center, filledRadius, Paint()..color = AppColors.primary);
        _drawCheck(canvas, center, filledRadius);
      }
    }

    _drawGapBracket(canvas, size, centers[3], centers[4]);
  }

  void _drawCheck(Canvas canvas, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx - radius * 0.35, center.dy)
      ..lineTo(center.dx - radius * 0.08, center.dy + radius * 0.32)
      ..lineTo(center.dx + radius * 0.4, center.dy - radius * 0.32);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.textOnPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.16
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawGapBracket(Canvas canvas, Size size, Offset dayA, Offset dayB) {
    final bracketTop = size.height * (102 / 180);
    final bracketBottom = size.height * (110 / 180);
    final tickBottom = size.height * (116 / 180);
    final midX = (dayA.dx + dayB.dx) / 2;

    final path = Path()
      ..moveTo(dayA.dx, bracketTop)
      ..cubicTo(
        dayA.dx,
        bracketBottom,
        dayA.dx + (midX - dayA.dx) * 0.4,
        bracketBottom,
        midX,
        bracketBottom,
      )
      ..cubicTo(
        dayB.dx - (dayB.dx - midX) * 0.4,
        bracketBottom,
        dayB.dx,
        bracketBottom,
        dayB.dx,
        bracketTop,
      );

    final bracketPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, bracketPaint);
    canvas.drawLine(
      Offset(midX, bracketBottom),
      Offset(midX, tickBottom),
      bracketPaint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '?',
        style: AppTypography.textTheme.headlineSmall?.copyWith(
          color: AppColors.accentText,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(midX - textPainter.width / 2, tickBottom + 4),
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashGap = 5.0;
    final totalDistance = (end - start).distance;
    final direction = (end - start) / totalDistance;
    var traveled = 0.0;
    while (traveled < totalDistance) {
      final segmentEnd = (traveled + dashWidth).clamp(0.0, totalDistance);
      canvas.drawLine(
        start + direction * traveled,
        start + direction * segmentEnd,
        paint,
      );
      traveled += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
