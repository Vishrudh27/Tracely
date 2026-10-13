import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:habit_tracker/core/constants/app_strings.dart';
import 'package:habit_tracker/features/splash/presentation/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders clock and animates brand typography', (tester) async {
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Dashboard')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
      ),
    );

    // Initial frame: CustomPaint for clock is present, Tracely text is at 0 opacity
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text(AppStrings.appName.toUpperCase()), findsOneWidget);

    // Advance 600ms (big hand sweeps around 360°, text fades in)
    await tester.pump(const Duration(milliseconds: 600));

    // Advance through completion and hold
    await tester.pump(const Duration(milliseconds: 700));

    // Final navigation settles to '/'
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
