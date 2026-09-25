import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';

/// Onboarding page 2's illustration: the Pause & Reflect sheet rising over a
/// linen notepad, one reason chip already chosen.
///
/// Traced from `onboarding_2/code.html`'s SVG, so every coordinate below is
/// in that file's 256×240 viewBox and scaled to whatever size it's given.
/// Bars stand in for text on purpose — the art stays sketch-like rather than
/// mocking real copy.
class ReasonPromptIllustration extends StatelessWidget {
  const ReasonPromptIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 256,
      height: 240,
      child: CustomPaint(painter: _ReasonPromptPainter()),
    );
  }
}

class _ReasonPromptPainter extends CustomPainter {
  const _ReasonPromptPainter();

  static const _viewBox = Size(256, 240);

  /// The sheet group is drawn 10px lower than its own coordinates, matching
  /// the SVG's `transform="translate(0, 10)"`.
  static const _sheetDrop = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewBox.width, size.height / _viewBox.height);

    _paintNotepad(canvas);
    _paintSheet(canvas);
    _paintLeaf(canvas);

    canvas.restore();
  }

  // The calm linen card everything else sits on.
  void _paintNotepad(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromLTRBR(28, 24, 228, 212, const Radius.circular(16)),
      Paint()..color = AppColors.surfaceVariant.withValues(alpha: 0.65),
    );

    final hairline = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Butt caps on the ruled lines: a round cap adds 0.75px at each end,
    // which eats a 3px gap and makes the dashes read as a solid rule.
    final ruled = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.5;

    _dashedLine(canvas, const Offset(48, 62), const Offset(208, 62), ruled);
    _dashedLine(canvas, const Offset(48, 92), const Offset(168, 92), ruled);

    // Quiet sun stamp, top right.
    canvas.drawCircle(
      const Offset(196, 48),
      8,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (final ray in const [
      [Offset(196, 36), Offset(196, 38)],
      [Offset(196, 58), Offset(196, 60)],
      [Offset(184, 48), Offset(186, 48)],
      [Offset(206, 48), Offset(208, 48)],
    ]) {
      canvas.drawLine(ray[0], ray[1], hairline);
    }
  }

  // The Pause & Reflect sheet itself, with its four reason chips.
  void _paintSheet(Canvas canvas) {
    canvas.save();
    canvas.translate(0, _sheetDrop);

    const sheet = Rect.fromLTWH(36, 84, 184, 138);
    const radius = Radius.circular(14);

    canvas.drawRRect(
      RRect.fromRectAndRadius(sheet.translate(0, 2), radius),
      Paint()..color = AppColors.primary.withValues(alpha: 0.04),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(sheet, radius),
      Paint()..color = AppColors.surface,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(sheet, radius),
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Drag handle.
    canvas.drawRRect(
      RRect.fromLTRBR(114, 94, 142, 97, const Radius.circular(1.5)),
      Paint()..color = AppColors.primary,
    );

    // Prompt lines.
    canvas.drawLine(
      const Offset(56, 116),
      const Offset(128, 116),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(56, 126),
      const Offset(96, 126),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    // The one chosen reason, in terracotta.
    _chip(
      canvas,
      const Rect.fromLTWH(52, 142, 72, 28),
      color: AppColors.accentTerracotta,
      fill: AppColors.surfaceVariant,
      strokeWidth: 2,
      dotRadius: 3.5,
      lineEnd: 112,
    );
    _chip(
      canvas,
      const Rect.fromLTWH(130, 142, 74, 28),
      color: AppColors.primary,
      fill: AppColors.background,
      strokeWidth: 1.5,
      dotRadius: 2.5,
      lineEnd: 191,
    );
    _chip(
      canvas,
      const Rect.fromLTWH(52, 178, 82, 28),
      color: AppColors.primary,
      fill: AppColors.background,
      strokeWidth: 1.5,
      dotRadius: 2.5,
      lineEnd: 122,
    );
    // The fourth chip is a dashed ghost — a reason not picked.
    _chip(
      canvas,
      const Rect.fromLTWH(140, 178, 64, 28),
      color: AppColors.border,
      fill: AppColors.background,
      strokeWidth: 1.5,
      dotRadius: 0,
      lineEnd: 188,
      lineColor: AppColors.textDisabled,
      dashed: true,
    );

    canvas.restore();
  }

  void _chip(
    Canvas canvas,
    Rect rect, {
    required Color color,
    required Color fill,
    required double strokeWidth,
    required double dotRadius,
    required double lineEnd,
    Color? lineColor,
    bool dashed = false,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    canvas.drawRRect(rrect, Paint()..color = fill);

    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (dashed) {
      _dashedRRect(canvas, rrect, border);
    } else {
      canvas.drawRRect(rrect, border);
    }

    final midY = rect.center.dy;
    var lineStart = rect.left + 14;

    if (dotRadius > 0) {
      canvas.drawCircle(
        Offset(rect.left + 13, midY),
        dotRadius,
        Paint()..color = color,
      );
      lineStart = rect.left + 23;
    }

    canvas.drawLine(
      Offset(lineStart, midY),
      Offset(lineEnd, midY),
      Paint()
        ..color = lineColor ?? color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  // The small terracotta leaf tucked against the right edge.
  void _paintLeaf(Canvas canvas) {
    final leaf = Path()
      ..moveTo(216, 112)
      ..cubicTo(224, 104, 230, 110, 226, 122)
      ..cubicTo(222, 134, 212, 128, 216, 112)
      ..close();
    canvas.drawPath(
      leaf,
      Paint()..color = AppColors.accentTerracotta.withValues(alpha: 0.85),
    );

    final vein = Path()
      ..moveTo(216, 126)
      ..cubicTo(222, 118, 225, 114, 227, 108);
    canvas.drawPath(
      vein,
      Paint()
        ..color = AppColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
  }

  // ---------------------------------------------------------------------------
  // Dash helpers — Flutter has no stroke-dasharray, so walk the path by hand.
  // ---------------------------------------------------------------------------

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    _dashedPath(canvas, Path()..moveTo(from.dx, from.dy)..lineTo(to.dx, to.dy),
        paint, 3, 3);
  }

  void _dashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    _dashedPath(canvas, Path()..addRRect(rrect), paint, 2, 2);
  }

  void _dashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dash,
    double gap,
  ) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_ReasonPromptPainter oldDelegate) => false;
}
