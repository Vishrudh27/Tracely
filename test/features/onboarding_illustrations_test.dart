import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/onboarding/presentation/widgets/first_habit_illustration.dart';
import 'package:habit_tracker/features/onboarding/presentation/widgets/reason_prompt_illustration.dart';
import 'package:habit_tracker/features/onboarding/presentation/widgets/streak_gap_illustration.dart';

/// The onboarding art is hand-painted from Stitch's SVGs, and a painter that
/// throws only shows up at paint time — analyze and the other tests never
/// touch it. This pumps each one and fails on any paint exception.
void main() {
  Future<void> pumpArt(WidgetTester tester, Widget art) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(height: 240, child: Center(child: art)),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('the streak gap illustration paints', (tester) async {
    await pumpArt(tester, const StreakGapIllustration());
  });

  testWidgets('the reason prompt illustration paints', (tester) async {
    await pumpArt(tester, const ReasonPromptIllustration());
  });

  testWidgets('the first habit illustration paints', (tester) async {
    await pumpArt(tester, const FirstHabitIllustration());
  });

  testWidgets('the reason prompt art keeps its Stitch viewBox', (tester) async {
    await pumpArt(tester, const ReasonPromptIllustration());
    expect(tester.getSize(find.byType(CustomPaint).last), const Size(256, 240));
  });
}
