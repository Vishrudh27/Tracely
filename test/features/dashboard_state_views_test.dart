import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/models/task_models.dart';
import 'package:habit_tracker/features/dashboard/presentation/widgets/dashboard_state_views.dart';

/// The empty and error views hand-paint an SVG glyph, and the loading view
/// builds a nested skeleton — all invisible to analyze. Pump each and fail on
/// any layout or paint exception.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: child)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  }

  testWidgets('empty view paints and its Add button fires', (tester) async {
    var tapped = false;
    await pump(tester, DashboardEmptyView(onAddHabit: () => tapped = true));
    await tester.tap(find.text('Add First Habit'));
    expect(tapped, isTrue);
  });

  testWidgets('error view paints and its Retry button fires', (tester) async {
    var retried = false;
    await pump(tester, DashboardErrorView(onRetry: () => retried = true));
    await tester.tap(find.text('Try Again'));
    expect(retried, isTrue);
  });

  testWidgets('loading skeleton paints', (tester) async {
    await pump(tester, const DashboardLoadingView());
  });

  group('DashboardRestDayView', () {
    const task = TaskWithCategory(
      id: 1,
      title: 'Water plants',
      dueDate: null,
      dueTime: null,
      priority: TaskPriority.normal,
      categoryName: 'Home',
      categoryEmoji: 'home',
      categoryColorValue: 0xFF78716C,
      notes: null,
      isDone: false,
    );

    testWidgets('paints with tasks and toggling fires the callback',
        (tester) async {
      int? toggledId;
      bool? toggledDone;
      await pump(
        tester,
        DashboardRestDayView(
          tasks: const [task],
          onToggleTask: (id, done) {
            toggledId = id;
            toggledDone = done;
          },
        ),
      );
      await tester.tap(find.byType(GestureDetector));
      expect(toggledId, 1);
      expect(toggledDone, isTrue);
    });

    testWidgets('paints with no tasks (Today\'s Tasks section just omitted)',
        (tester) async {
      await pump(
        tester,
        DashboardRestDayView(tasks: const [], onToggleTask: (_, _) {}),
      );
      expect(find.text('Nothing due today'), findsOneWidget);
    });

    testWidgets('the settings gear only shows when a callback is given',
        (tester) async {
      await pump(
        tester,
        DashboardRestDayView(tasks: const [], onToggleTask: (_, _) {}),
      );
      expect(find.byIcon(Icons.settings_outlined), findsNothing);

      await pump(
        tester,
        DashboardRestDayView(
          tasks: const [],
          onToggleTask: (_, _) {},
          onSettingsTap: () {},
        ),
      );
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });
  });
}
