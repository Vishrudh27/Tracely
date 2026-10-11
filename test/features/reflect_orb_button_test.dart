import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/providers/current_date_provider.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/features/reflection/presentation/providers/reflection_prompt_providers.dart';
import 'package:habit_tracker/features/reflection/presentation/widgets/reflect_orb_button.dart';
import 'package:habit_tracker/features/reflection/presentation/widgets/reflection_orb.dart';

class _FakeCurrentDateNotifier extends CurrentDateNotifier {
  _FakeCurrentDateNotifier(this._date);
  final DateTime _date;

  @override
  DateTime build() => _date;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReflectOrbButton', () {
    final fixedToday = DateTime(2026, 10, 11);

    HabitReflection makeReflection(List<String> keys, {String? customText}) {
      return HabitReflection(
        id: 1,
        reflectionDate: fixedToday,
        reasonKeys: jsonEncode(keys),
        customText: customText,
        missedHabitIds: '[]',
        createdAt: fixedToday,
        updatedAt: fixedToday,
      );
    }

    testWidgets('shows 0.0 progress when no reflection exists', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentDateProvider.overrideWith(
              () => _FakeCurrentDateNotifier(fixedToday),
            ),
            reflectionForDateProvider(fixedToday).overrideWith(
              (ref) => Stream.value(null),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReflectOrbButton(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final orb = tester.widget<ReflectionOrb>(find.byType(ReflectionOrb));
      expect(orb.progress, 0.0);
    });

    testWidgets('shows 0.5 progress when 1 stone is recorded', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentDateProvider.overrideWith(
              () => _FakeCurrentDateNotifier(fixedToday),
            ),
            reflectionForDateProvider(fixedToday).overrideWith(
              (ref) => Stream.value(makeReflection(['low_energy'])),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReflectOrbButton(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final orb = tester.widget<ReflectionOrb>(find.byType(ReflectionOrb));
      expect(orb.progress, 0.5);
    });

    testWidgets('shows 1.0 progress when 2 stones are recorded', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentDateProvider.overrideWith(
              () => _FakeCurrentDateNotifier(fixedToday),
            ),
            reflectionForDateProvider(fixedToday).overrideWith(
              (ref) => Stream.value(makeReflection(['low_energy', 'poor_sleep'])),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReflectOrbButton(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final orb = tester.widget<ReflectionOrb>(find.byType(ReflectionOrb));
      expect(orb.progress, 1.0);
    });
  });
}
