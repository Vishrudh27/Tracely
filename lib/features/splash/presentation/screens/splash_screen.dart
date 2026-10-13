import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';

/// Concept A: Habit Rings & Orbital Wave (~750ms total sequence).
///
/// Features:
/// 1. [0.00..0.48]: The big hand swiftly sweeps 360°, illuminating 7 concentric
///    habit-orbit pips in a domino wave and advancing the hour hand to 12:00.
/// 2. [0.46..0.65]: Elastic tactile micro-snap at 12:00 with an expanding orbital wave.
/// 3. [0.46..0.72]: Luxury tracking typography: "TRACELY" expands tracking and fades in.
/// 4. [0.78..1.00]: Ultra-smooth hardware dissolve exit into the app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _clockSweep;
  late final Animation<double> _clockScale;
  late final Animation<double> _waveProgress;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textTracking;
  late final Animation<double> _textSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _exitOpacity;
  late final Animation<double> _exitScale;

  @override
  void initState() {
    super.initState();
    // Total sequence: 750ms (ultra-fast, zero GPU stalls)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    // 1. Clock big hand sweeps full 360° circle (0.0 -> 1.0)
    _clockSweep = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.48, curve: Curves.fastOutSlowIn),
    );

    // 2. Micro-elastic tactile snap when hands align at 12:00
    _clockScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 48,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 26,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 26,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.66),
      ),
    );

    // 3. Orbital shockwave expansion at 12:00
    _waveProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.46, 0.68, curve: Curves.easeOutCubic),
    );

    // 4. Luxury tracking typography
    _textOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.46, 0.70, curve: Curves.easeOut),
    );
    _textTracking = Tween<double>(begin: 4.2, end: 1.4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.46, 0.72, curve: Curves.easeOutCubic),
      ),
    );
    _textSlide = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.46, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    // 5. Tagline reveal
    _taglineOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.54, 0.76, curve: Curves.easeOut),
    );

    // 6. Fluid exit dissolve ("and it should go")
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.78, 1.00, curve: Curves.easeInOut),
      ),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.78, 1.00, curve: Curves.easeInCubic),
      ),
    );

    _run();
  }

  Future<void> _run() async {
    await _controller.forward();
    if (!mounted) return;
    context.go(AppRouter.reflection);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Align(
        alignment: const Alignment(0, -0.06),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Opacity(
              opacity: _exitOpacity.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _exitScale.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Concentric Habit Rings & Orbital Dial
                    RepaintBoundary(
                      child: Transform.scale(
                        scale: _clockScale.value,
                        child: SizedBox(
                          width: 130,
                          height: 130,
                          child: CustomPaint(
                            painter: _OrbitalClockPainter(
                              sweepProgress: _clockSweep.value,
                              waveProgress: _waveProgress.value,
                              primaryColor: AppColors.primary,
                              accentColor: AppColors.clay,
                              borderColor: AppColors.border,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    // Luxury Tracking Typography
                    Opacity(
                      opacity: _textOpacity.value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppStrings.appName.toUpperCase(),
                              style: context.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: _textTracking.value,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Opacity(
                              opacity: _taglineOpacity.value.clamp(0.0, 1.0),
                              child: Text(
                                AppStrings.appTagline,
                                textAlign: TextAlign.center,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Concept A Painter:
/// - Inner Swiss Dial with 12 hour ticks and hands.
/// - Concentric Outer Habit Orbit with 7 day-dots lighting up in a domino wave.
/// - Expanding orbital wave at 12:00.
/// - Zero software-blur masks for pure 120 FPS hardware rasterization.
class _OrbitalClockPainter extends CustomPainter {
  const _OrbitalClockPainter({
    required this.sweepProgress,
    required this.waveProgress,
    required this.primaryColor,
    required this.accentColor,
    required this.borderColor,
  });

  final double sweepProgress;
  final double waveProgress;
  final Color primaryColor;
  final Color accentColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const dialRadius = 35.0;
    const orbitRadius = 52.0;

    // 1. Warm ambient background aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: 0.12),
          accentColor.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: orbitRadius + 12));
    canvas.drawCircle(center, orbitRadius + 12, auraPaint);

    // 2. Outer Concentric Habit Orbit Ring (faint guide track)
    final orbitTrackPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, orbitRadius, orbitTrackPaint);

    // 3. 7 Habit-Pips around the orbit (representing 7-day habit streak cycle)
    const habitPipCount = 7;
    for (var i = 0; i < habitPipCount; i++) {
      final pipProgress = i / habitPipCount;
      final pipAngle = -math.pi / 2 + (2.0 * math.pi * pipProgress);
      final pipOffset = Offset(
        center.dx + orbitRadius * math.cos(pipAngle),
        center.dy + orbitRadius * math.sin(pipAngle),
      );

      final isIlluminated = sweepProgress >= (pipProgress - 0.02);

      if (isIlluminated) {
        // Active golden habit pip with soft halo
        final haloPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pipOffset, 4.5, haloPaint);

        final dotPaint = Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pipOffset, 2.4, dotPaint);
      } else {
        // Dormant pip
        final dotPaint = Paint()
          ..color = borderColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pipOffset, 1.6, dotPaint);
      }
    }

    // 4. Expanding Orbital Shockwave at 12:00 completion
    if (waveProgress > 0.01 && waveProgress < 0.99) {
      final waveRadius = dialRadius + (waveProgress * (orbitRadius + 8 - dialRadius));
      final waveAlpha = (1.0 - waveProgress) * 0.45;
      final wavePaint = Paint()
        ..color = accentColor.withValues(alpha: waveAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - waveProgress);
      canvas.drawCircle(center, waveRadius, wavePaint);
    }

    // 5. Inner Dial Bezel
    final dialPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, dialRadius, dialPaint);

    // 6. Hour tick markers (12 ticks)
    final tickPaintMajor = Paint()
      ..color = primaryColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final tickPaintMinor = Paint()
      ..color = borderColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 12; i++) {
      final angle = (i * 30.0) * math.pi / 180.0;
      final isMajor = i % 3 == 0; // 12, 3, 6, 9
      final tickLength = isMajor ? 4.5 : 2.5;

      final startOffset = Offset(
        center.dx + (dialRadius - tickLength) * math.sin(angle),
        center.dy - (dialRadius - tickLength) * math.cos(angle),
      );
      final endOffset = Offset(
        center.dx + (dialRadius - 1.0) * math.sin(angle),
        center.dy - (dialRadius - 1.0) * math.cos(angle),
      );

      canvas.drawLine(
        startOffset,
        endOffset,
        isMajor ? tickPaintMajor : tickPaintMinor,
      );
    }

    // 7. Golden Amber trail arc traced by the big hand
    if (sweepProgress > 0.01) {
      final sweepAngle = 2.0 * math.pi * sweepProgress.clamp(0.0, 1.0);
      final arcRect = Rect.fromCircle(center: center, radius: dialRadius - 2.0);
      final trailPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(arcRect, -math.pi / 2, sweepAngle, false, trailPaint);
    }

    // 8. Hour hand (advances smoothly from 11:00 to 12:00)
    final hourAngle =
        (-math.pi / 2) - ((math.pi / 6.0) * (1.0 - sweepProgress.clamp(0.0, 1.0)));
    final hourLength = dialRadius * 0.48;
    final hourHandPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + hourLength * math.cos(hourAngle),
        center.dy + hourLength * math.sin(hourAngle),
      ),
      hourHandPaint,
    );

    // 9. Big Hand (Minute hand) — sweeps 360°
    final minuteAngle =
        -math.pi / 2 + (2.0 * math.pi * sweepProgress.clamp(0.0, 1.0));
    final minuteLength = dialRadius * 0.76;
    final minuteHandPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + minuteLength * math.cos(minuteAngle),
        center.dy + minuteLength * math.sin(minuteAngle),
      ),
      minuteHandPaint,
    );

    // Golden tip accent dot
    final tipOffset = Offset(
      center.dx + minuteLength * math.cos(minuteAngle),
      center.dy + minuteLength * math.sin(minuteAngle),
    );
    canvas.drawCircle(tipOffset, 1.8, Paint()..color = accentColor);

    // 10. Center pivot pin
    canvas.drawCircle(center, 3.0, Paint()..color = accentColor);
    canvas.drawCircle(center, 1.2, Paint()..color = primaryColor);
  }

  @override
  bool shouldRepaint(_OrbitalClockPainter oldDelegate) =>
      oldDelegate.sweepProgress != sweepProgress ||
      oldDelegate.waveProgress != waveProgress ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.borderColor != borderColor;
}
