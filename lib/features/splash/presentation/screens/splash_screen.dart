import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';

/// First frame of the app — emblem, wordmark, tagline, then out of the way.
///
/// Purely presentational. It hands off to `/`, whose redirect already decides
/// between onboarding, the morning ritual and the dashboard, so the gate
/// logic stays in one place. What this screen buys is a branded frame over
/// the cold start instead of a blank one.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Long enough for the animation to land and read as intentional, short
  /// enough not to be a toll booth on every launch.
  static const _holdAfterAnimation = Duration(milliseconds: 450);

  late final AnimationController _controller;
  late final Animation<double> _emblemOpacity;
  late final Animation<double> _emblemScale;
  late final Animation<double> _wordmarkOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );

    // Stitch: 900ms opacity + scale 0.96 → 1 on the emblem.
    const emblemCurve = Interval(0.0, 0.857, curve: Curves.easeOutExpo);
    _emblemOpacity = CurvedAnimation(parent: _controller, curve: emblemCurve);
    _emblemScale = Tween<double>(begin: 0.96, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: emblemCurve));

    // Stitch: wordmark and tagline fade over 700ms, 150ms behind the emblem.
    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.143, 1.0, curve: Curves.easeOut),
    );

    _run();
  }

  Future<void> _run() async {
    await _controller.forward();
    await Future<void>.delayed(_holdAfterAnimation);
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
        // Stitch centres inside 85vh, which sits a little above true centre.
        alignment: const Alignment(0, -0.15),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _emblemOpacity.value,
                  child: Transform.scale(
                    scale: _emblemScale.value,
                    child: const _LoopEmblem(),
                  ),
                ),
                Opacity(
                  opacity: _wordmarkOpacity.value,
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        AppStrings.appName,
                        style: context.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.7, // tracking-wide at 28px
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        AppStrings.appTagline,
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tracely's mark: a thin ring left open at the top — a loop not yet closed.
///
/// Stitch serves this as a hosted PNG, so it's drawn from `splash/screen.png`
/// instead: no asset to bundle, no density to pick, and it takes the theme's
/// colour. The one detail not reproduced is the slight overlap where the two
/// ends pass each other; this draws a clean gap.
class _LoopEmblem extends StatelessWidget {
  const _LoopEmblem();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(painter: _LoopPainter()),
    );
  }
}

class _LoopPainter extends CustomPainter {
  const _LoopPainter();

  /// Radians of ring left open, centred at 12 o'clock.
  static const _gap = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.0375;
    final arc = (Offset.zero & size).deflate(stroke / 2);

    canvas.drawArc(
      arc,
      -1.5708 + _gap / 2, // 12 o'clock, past half the gap
      6.2832 - _gap,
      false,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LoopPainter oldDelegate) => false;
}
