import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/providers/current_date_provider.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../../../../data/services/reflection_gate_service.dart';

/// The hour at which the evening reflection prompt becomes eligible (18:00 = 6:00 PM).
const int kEveningPromptHour = 18;

/// States for the contextual Pause & Reflect prompt.
enum ReflectionPromptState {
  /// No contextual reflection card shown.
  none,

  /// Yesterday had missed habits that remain unreflected and unskipped.
  /// Takes highest priority and persists all day until logged or skipped.
  morningAfter,

  /// Today has incomplete habits and the local hour is >= 18:00 (6:00 PM).
  evening,
}

/// Provider for the current clock function (defaults to [DateTime.now]).
final nowFnProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Watches the database reflection record for a specific calendar [date].
final reflectionForDateProvider =
    StreamProvider.family<HabitReflection?, DateTime>((ref, date) {
  final dao = ref.watch(reflectionDaoProvider);
  return dao.watchReflectionForDate(date);
});

/// Riverpod notifier managing the contextual prompt state.
///
/// Automatically recomputes:
/// 1. When habit completions toggle today (via [todaysHabitsProvider]).
/// 2. When reflections are created or updated for yesterday or today.
/// 3. When calendar day changes (via [currentDateProvider]).
/// 4. When app lifecycle state transitions to [AppLifecycleState.resumed].
/// 5. When the clock crosses [kEveningPromptHour] (via scheduled timer).
class ReflectionPromptStateNotifier
    extends AsyncNotifier<ReflectionPromptState>
    with WidgetsBindingObserver {
  Timer? _eveningTimer;

  @override
  Future<ReflectionPromptState> build() async {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _eveningTimer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });

    final today = ref.watch(currentDateProvider);
    final yesterday = today.addDays(-1);

    // Watch habit completions so completing a habit recomputes immediately
    ref.watch(todaysHabitsProvider);

    // Watch reflection rows for yesterday and today
    final yesterdayReflection =
        ref.watch(reflectionForDateProvider(yesterday)).asData?.value;
    final todayReflection =
        ref.watch(reflectionForDateProvider(today)).asData?.value;

    final nowFn = ref.watch(nowFnProvider);
    final now = nowFn();
    _scheduleEveningTimer(nowFn);

    // -------------------------------------------------------------------------
    // Priority 1: morningAfter
    // Yesterday had missed habits AND no reflection for yesterday AND not skipped
    // -------------------------------------------------------------------------
    final yesterdaySkipped =
        await ReflectionGateService.isDateSkipped(yesterday);
    if (yesterdayReflection == null && !yesterdaySkipped) {
      final yesterdayMissed = await ref
          .read(habitRepositoryProvider)
          .getMissedHabitsForDate(yesterday);
      if (yesterdayMissed.isNotEmpty) {
        return ReflectionPromptState.morningAfter;
      }
    }

    // -------------------------------------------------------------------------
    // Priority 2: evening
    // Hour >= 18, today has incomplete habits, no reflection today, not skipped
    // -------------------------------------------------------------------------
    final todaySkipped = await ReflectionGateService.isDateSkipped(today);
    if (now.hour >= kEveningPromptHour &&
        todayReflection == null &&
        !todaySkipped) {
      final todayIncomplete = await ref
          .read(habitRepositoryProvider)
          .getMissedHabitsForDate(today);
      if (todayIncomplete.isNotEmpty) {
        return ReflectionPromptState.evening;
      }
    }

    return ReflectionPromptState.none;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidateSelf();
    }
  }

  void _scheduleEveningTimer(DateTime Function() nowFn) {
    _eveningTimer?.cancel();
    final now = nowFn();
    if (now.hour < kEveningPromptHour) {
      final eveningTime =
          DateTime(now.year, now.month, now.day, kEveningPromptHour);
      final delay = eveningTime.difference(now) + const Duration(seconds: 1);
      _eveningTimer = Timer(delay, () => ref.invalidateSelf());
    }
  }

  /// Marks [date] as skipped and triggers immediate recomputation.
  Future<void> skip(DateTime date) async {
    await ReflectionGateService.markDateSkipped(date);
    ref.invalidateSelf();
  }

  /// Refreshes prompt state immediately.
  void refresh() {
    ref.invalidateSelf();
  }
}

/// Provider for contextual prompt state: none, morningAfter, or evening.
final reflectionPromptStateProvider = AsyncNotifierProvider<
    ReflectionPromptStateNotifier, ReflectionPromptState>(
  ReflectionPromptStateNotifier.new,
);
