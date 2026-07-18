import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../widgets/animated_continue_button.dart';
import '../widgets/animated_greeting.dart';
import '../widgets/animated_quote_card.dart';
import '../widgets/reflection_background.dart';

class ReflectionScreen extends StatefulWidget {
  const ReflectionScreen({super.key});

  @override
  State<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
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
