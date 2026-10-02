import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extensions/date_extensions.dart';
import '../../core/providers/current_date_provider.dart';
import '../../core/utils/behavior_insights.dart';
import '../../core/utils/habit_schedule.dart';
import '../services/database_service.dart';
import '../services/insight_service.dart';
import 'habit_repository.dart';

/// Settings' Smart suggestions toggle. Mirrors [ReduceMotionNotifier].
class SmartSuggestionsNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => InsightService.isEnabled();

  Future<void> setEnabled(bool enabled) async {
    await InsightService.setEnabled(enabled);
    state = AsyncData(enabled);
  }
}

final smartSuggestionsProvider =
    AsyncNotifierProvider<SmartSuggestionsNotifier, bool>(
  SmartSuggestionsNotifier.new,
);

/// Keys of suggestion cards the user has closed.
class DismissedInsightsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() => InsightService.loadDismissed();

  Future<void> dismiss(String key) async {
    await InsightService.dismiss(key);
    state = AsyncData({...?state.asData?.value, key});
  }
}

final dismissedInsightsProvider =
    AsyncNotifierProvider<DismissedInsightsNotifier, Set<String>>(
  DismissedInsightsNotifier.new,
);

/// The one Dashboard suggestion to show, or null.
///
/// ponytail: recomputed on habit edits, dismissals and day change — not on
/// every completion. Fine for a 30-day median.
final behaviorInsightProvider = FutureProvider<BehaviorInsight?>((ref) async {
  // Every watch before the first await, so all dependencies register.
  final enabledF = ref.watch(smartSuggestionsProvider.future);
  final dismissedF = ref.watch(dismissedInsightsProvider.future);
  final habitsF = ref.watch(activeHabitsProvider.future);
  final today = ref.watch(currentDateProvider);
  final db = ref.watch(appDatabaseProvider);

  if (!await enabledF) return null;
  final habits = await habitsF;
  final byHabit = groupBy(
    await db.completionDao.getAllCompletionsSince(today.addDays(-29)),
    (c) => c.habitId,
  );

  final inputs = <HabitTimingInput>[];
  for (final h in habits) {
    final reminder = h.reminderEnabled ? parseHhMm(h.reminderTime) : null;
    var energyMisses = 0;
    if (reminder != null && reminder >= 20 * 60) {
      // Default limit (3) would hide energy keys behind other reasons.
      final reasons = await db.reflectionDao
          .watchMostCommonReasonsForHabit(h.id, limit: 50)
          .first;
      energyMisses = reasons
          .where((r) => kEnergyReasonKeys.contains(r.reason))
          .fold(0, (sum, r) => sum + r.count);
    }
    inputs.add(HabitTimingInput(
      habitId: h.id,
      name: h.name,
      reminderMinute: reminder,
      completedAts: [for (final c in byHabit[h.id] ?? const []) c.completedAt],
      energyMisses: energyMisses,
    ));
  }

  return pickBehaviorInsight(inputs, today: today, dismissed: await dismissedF);
});
