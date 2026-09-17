import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/quote_constants.dart';
import '../../../../data/services/database_service.dart';
import '../../../../data/services/reflection_gate_service.dart';
import '../widgets/animated_continue_button.dart';
import '../widgets/animated_greeting.dart';
import '../widgets/animated_quote_card.dart';
import '../widgets/reflection_background.dart';

/// The Daily Opening Ritual — Tracely's morning entry point.
///
/// Shown once per morning (before noon, once per day). The gate is
/// enforced at the router level via ReflectionGateService.
///
/// On init:
/// - Marks the reflection as shown for today (via ReflectionGateService)
/// - Persists today's quote to DailyReflections (so Statistics can track it)
///
/// Entrance animation: 2000ms single AnimationController.
///   Interval 0.00–0.55 → greeting fades in + moves to top
///   Interval 0.45–0.80 → quote card slides up + glows
///   Interval 0.80–1.00 → continue button appears
class ReflectionScreen extends ConsumerStatefulWidget {
  const ReflectionScreen({super.key});

  @override
  ConsumerState<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends ConsumerState<ReflectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      // 2000ms — slightly faster than original 2500ms, still intentionally slow.
      // The deliberate pace IS the feature: it's a designed emotional reset.
      duration: const Duration(milliseconds: 2000),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _controller.forward();

      // Mark the reflection as shown for today so the gate doesn't trigger again
      await ReflectionGateService.markShown();

      // Persist today's shown quote to DailyReflections
      final quote = QuoteConstants.todaysQuote();
      try {
        final db = ref.read(appDatabaseProvider);
        await db.reflectionDao.recordReflection(shownQuote: quote.text);
      } catch (_) {
        // Non-fatal — reflection record failure should never block the user
      }
    });
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
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return ReflectionBackground(animation: _controller);
              },
            ),

            AnimatedGreeting(controller: _controller),

            AnimatedQuoteCard(controller: _controller),

            AnimatedContinueButton(controller: _controller),
          ],
        ),
      ),
    );
  }
}
