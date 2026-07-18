import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/daos/category_dao.dart';
import '../database/daos/completion_dao.dart';
import '../database/daos/habit_dao.dart';
import '../models/habit_models.dart';
import '../services/database_service.dart';
import '../../core/extensions/date_extensions.dart';
import '../../core/utils/streak_calculator.dart';

/// Repository providing all habit-related data to the presentation layer.
///
/// Combines HabitDao + CompletionDao + CategoryDao to produce rich
/// domain objects. This is the single point of contact for the UI.
class HabitRepository {
  const HabitRepository(this._habitDao, this._completionDao, this._categoryDao);

  final HabitDao _habitDao;
  final CompletionDao _completionDao;
  final CategoryDao _categoryDao;

  // ---------------------------------------------------------------------------
  // Dashboard: Today's habits with completion status
  // ---------------------------------------------------------------------------

  /// Watch today's active habits with their completion status.
  ///
  /// FIXED: Merges both habits stream AND completions stream so toggling
  /// a completion updates the dashboard list reactively in real time.
  Stream<List<HabitWithCompletion>> watchTodaysHabits() {
    final today = DateTime.now().startOfDay;
    final controller = StreamController<List<HabitWithCompletion>>();

    List<Habit> latestHabits = [];
    List<HabitCompletion> latestCompletions = [];
    bool habitsLoaded = false;
    bool completionsLoaded = false;

    Future<void> emit() async {
      if (!habitsLoaded || !completionsLoaded) return;
      if (controller.isClosed) return;
      final categories = await _categoryDao.getActiveCategories();
      final catMap = {for (final c in categories) c.id: c};
      final completedIds = {for (final c in latestCompletions) c.habitId};

      final result = <HabitWithCompletion>[];
      for (final habit in latestHabits) {
        if (!_isHabitScheduledForDay(habit, today)) continue;
        final cat = catMap[habit.categoryId];
        result.add(
          HabitWithCompletion(
            habitId: habit.id,
            name: habit.name,
            emoji: habit.emoji ?? cat?.emoji ?? '✨',
            categoryName: cat?.name ?? 'General',
            categoryEmoji: cat?.emoji ?? '✨',
            categoryColorValue: cat?.colorValue ?? 0xFF78716C,
            frequencyType: habit.frequencyType,
            frequencyConfig: habit.frequencyConfig,
            isCompletedToday: completedIds.contains(habit.id),
            sortOrder: habit.sortOrder,
          ),
        );
      }
      controller.add(result);
    }

    StreamSubscription<List<Habit>>? habitSub;
    StreamSubscription<List<HabitCompletion>>? completionSub;

    habitSub = _habitDao.watchActiveHabits().listen((habits) {
      latestHabits = habits;
      habitsLoaded = true;
      emit();
    }, onError: controller.addError);

    completionSub =
        _completionDao.watchCompletionsForDate(today).listen((completions) {
      latestCompletions = completions;
      completionsLoaded = true;
      emit();
    }, onError: controller.addError);

    controller.onCancel = () {
      habitSub?.cancel();
      completionSub?.cancel();
    };

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Dashboard: Daily progress
  // ---------------------------------------------------------------------------

  /// Watch today's overall completion progress as a reactive stream.
  ///
  /// Reacts to BOTH habit changes AND completion changes.
  Stream<DailyProgress> watchTodaysProgress() {
    final today = DateTime.now().startOfDay;
    final controller = StreamController<DailyProgress>();

    List<Habit> latestHabits = [];
    List<HabitCompletion> latestCompletions = [];
    bool habitsLoaded = false;
    bool completionsLoaded = false;

    void emit() {
      if (!habitsLoaded || !completionsLoaded) return;
      if (controller.isClosed) return;
      final todaysHabits =
          latestHabits
              .where((h) => _isHabitScheduledForDay(h, today))
              .toList();
      final completedIds = {for (final c in latestCompletions) c.habitId};
      final completedCount =
          todaysHabits.where((h) => completedIds.contains(h.id)).length;
      controller.add(
        DailyProgress(
          completedCount: completedCount,
          totalCount: todaysHabits.length,
        ),
      );
    }

    StreamSubscription<List<Habit>>? habitSub;
    StreamSubscription<List<HabitCompletion>>? completionSub;

    habitSub = _habitDao.watchActiveHabits().listen((habits) {
      latestHabits = habits;
      habitsLoaded = true;
      emit();
    }, onError: controller.addError);

    completionSub =
        _completionDao.watchCompletionsForDate(today).listen((completions) {
      latestCompletions = completions;
      completionsLoaded = true;
      emit();
    }, onError: controller.addError);

    controller.onCancel = () {
      habitSub?.cancel();
      completionSub?.cancel();
    };

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Dashboard: Weekly heatmap strip (7 days)
  // ---------------------------------------------------------------------------

  /// Watch the current week's completion data for the heatmap strip.
  Stream<List<DayCompletion>> watchWeeklyHeatmap() async* {
    final today = DateTime.now().startOfDay;
    final weekStart = today.startOfWeek;

    await for (final _ in _completionDao.watchWeekCompletions(weekStart)) {
      final days = <DayCompletion>[];
      final habits = await _habitDao.getActiveHabits();

      for (int i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final scheduledHabits =
            habits.where((h) => _isHabitScheduledForDay(h, day)).toList();

        if (scheduledHabits.isEmpty) {
          days.add(DayCompletion(date: day, completionPercentage: 0));
          continue;
        }

        int completedCount = 0;
        for (final habit in scheduledHabits) {
          if (await _completionDao.isCompleted(habit.id, day)) completedCount++;
        }

        days.add(
          DayCompletion(
            date: day,
            completionPercentage: completedCount / scheduledHabits.length,
          ),
        );
      }
      yield days;
    }
  }

  // ---------------------------------------------------------------------------
  // Dashboard: Recent activity
  // ---------------------------------------------------------------------------

  /// Watch the most recent completions across all habits.
  Stream<List<CompletionWithHabit>> watchRecentCompletions({
    int limit = 3,
  }) async* {
    await for (final completions
        in _completionDao.watchRecentCompletions(limit: limit)) {
      final result = <CompletionWithHabit>[];
      for (final c in completions) {
        final habit = await _habitDao.getHabitById(c.habitId);
        if (habit == null) continue;
        final cat = await _categoryDao.getCategoryById(habit.categoryId);
        result.add(
          CompletionWithHabit(
            completionId: c.id,
            habitId: c.habitId,
            habitName: habit.name,
            habitEmoji: habit.emoji ?? cat?.emoji ?? '✨',
            completedAt: c.completedAt,
            completedDate: c.completedDate,
          ),
        );
      }
      yield result;
    }
  }

  // ---------------------------------------------------------------------------
  // Toggle completion
  // ---------------------------------------------------------------------------

  /// Toggle today's completion for a habit.
  Future<void> toggleCompletion(int habitId) async {
    final today = DateTime.now().startOfDay;
    await _completionDao.toggleCompletion(habitId, today);
  }

  // ---------------------------------------------------------------------------
  // Statistics: Heatmap data (N months)
  // ---------------------------------------------------------------------------

  /// Watch heatmap data for the last [months] months.
  ///
  /// Returns a map of date → completion percentage (0.0–1.0).
  Stream<Map<DateTime, double>> watchHeatmapData({required int months}) async* {
    final today = DateTime.now().startOfDay;
    final since = DateTime(today.year, today.month - months, today.day);

    // Emit on startup, then re-emit whenever today's completions change
    yield await _buildHeatmapData(since, today);

    await for (final _ in _completionDao.watchCompletionsForDate(today)) {
      yield await _buildHeatmapData(since, today);
    }
  }

  Future<Map<DateTime, double>> _buildHeatmapData(
    DateTime since,
    DateTime until,
  ) async {
    final completions = await _completionDao.getCompletionsInRange(since, until);
    final habits = await _habitDao.getActiveHabits();

    // Group completions by date → set of habitIds
    final byDate = <DateTime, Set<int>>{};
    for (final c in completions) {
      final day = c.completedDate.startOfDay;
      byDate.putIfAbsent(day, () => {}).add(c.habitId);
    }

    final result = <DateTime, double>{};
    var day = since;
    while (!day.isAfter(until)) {
      final scheduledHabits =
          habits.where((h) => _isHabitScheduledForDay(h, day)).toList();
      if (scheduledHabits.isNotEmpty) {
        final completedIds = byDate[day] ?? {};
        result[day] =
            (completedIds.length / scheduledHabits.length).clamp(0.0, 1.0);
      }
      day = day.add(const Duration(days: 1));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Statistics: Completion trend (daily % over N days)
  // ---------------------------------------------------------------------------

  /// Watch the daily completion percentage over the last [days] days.
  Stream<List<DailyCompletion>> watchCompletionTrend({
    required int days,
  }) async* {
    final today = DateTime.now().startOfDay;
    final since = today.subtract(Duration(days: days - 1));

    yield await _buildTrend(since, today, days);

    await for (final _ in _completionDao.watchCompletionsForDate(today)) {
      yield await _buildTrend(since, today, days);
    }
  }

  Future<List<DailyCompletion>> _buildTrend(
    DateTime since,
    DateTime until,
    int days,
  ) async {
    final completions = await _completionDao.getCompletionsInRange(since, until);
    final habits = await _habitDao.getActiveHabits();

    final byDate = <DateTime, Set<int>>{};
    for (final c in completions) {
      final day = c.completedDate.startOfDay;
      byDate.putIfAbsent(day, () => {}).add(c.habitId);
    }

    final result = <DailyCompletion>[];
    for (int i = 0; i < days; i++) {
      final day = since.add(Duration(days: i));
      final scheduledHabits =
          habits.where((h) => _isHabitScheduledForDay(h, day)).toList();
      final completedIds = byDate[day] ?? {};
      final pct = scheduledHabits.isEmpty
          ? 0.0
          : (completedIds.length / scheduledHabits.length).clamp(0.0, 1.0);
      result.add(DailyCompletion(date: day, percentage: pct));
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Statistics: Per-habit breakdown
  // ---------------------------------------------------------------------------

  /// Watch per-habit breakdown statistics for the last 30 days.
  Stream<List<HabitBreakdown>> watchHabitBreakdowns() async* {
    final today = DateTime.now().startOfDay;
    final since = today.subtract(const Duration(days: 29));

    yield await _buildHabitBreakdowns(today, since);

    await for (final _ in _habitDao.watchActiveHabits()) {
      yield await _buildHabitBreakdowns(today, since);
    }
  }

  Future<List<HabitBreakdown>> _buildHabitBreakdowns(
    DateTime today,
    DateTime since,
  ) async {
    final habits = await _habitDao.getActiveHabits();
    final categories = await _categoryDao.getActiveCategories();
    final catMap = {for (final c in categories) c.id: c};

    final result = <HabitBreakdown>[];
    for (final habit in habits) {
      // Last 30 days completions
      final recent = await _completionDao.getCompletionsForHabit(
        habit.id,
        since: since,
      );
      // All time completions for streak
      final allTime = await _completionDao.getCompletionsForHabit(habit.id);

      int scheduledDays = 0;
      for (int i = 0; i < 30; i++) {
        final day = since.add(Duration(days: i));
        if (!day.isAfter(today) && _isHabitScheduledForDay(habit, day)) {
          scheduledDays++;
        }
      }

      final allDates = allTime.map((c) => c.completedDate).toList();
      final cat = catMap[habit.categoryId];

      result.add(
        HabitBreakdown(
          habitId: habit.id,
          name: habit.name,
          emoji: habit.emoji ?? cat?.emoji ?? '✨',
          categoryColorValue: cat?.colorValue ?? 0xFF78716C,
          completionRate: scheduledDays == 0
              ? 0.0
              : (recent.length / scheduledDays).clamp(0.0, 1.0),
          currentStreak: StreakCalculator.currentStreak(allDates),
          longestStreak: StreakCalculator.longestStreak(allDates),
          totalCompletions: allTime.length,
        ),
      );
    }

    result.sort((a, b) => b.completionRate.compareTo(a.completionRate));
    return result;
  }

  // ---------------------------------------------------------------------------
  // Statistics: Overall streak
  // ---------------------------------------------------------------------------

  /// Watch the overall streak — any habit completed on a day counts.
  Stream<StreakData> watchOverallStreak() async* {
    final today = DateTime.now().startOfDay;

    yield await _computeOverallStreak();

    await for (final _ in _completionDao.watchCompletionsForDate(today)) {
      yield await _computeOverallStreak();
    }
  }

  Future<StreakData> _computeOverallStreak() async {
    final allCompletions = await _completionDao.getAllCompletionsSince(
      DateTime(2020),
    );
    final uniqueDates = <DateTime>{};
    for (final c in allCompletions) {
      uniqueDates.add(c.completedDate.startOfDay);
    }
    final sortedDates = uniqueDates.toList()..sort();
    return StreakData(
      currentStreak: StreakCalculator.currentStreak(sortedDates),
      longestStreak: StreakCalculator.longestStreak(sortedDates),
      lastCompletedDate: sortedDates.isNotEmpty ? sortedDates.last : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Statistics: Weekly insight
  // ---------------------------------------------------------------------------

  /// Generate a positive weekly insight based on this week's completions.
  Stream<WeeklyInsight> watchWeeklyInsight() async* {
    final today = DateTime.now().startOfDay;
    final weekStart = today.startOfWeek;

    yield await _computeWeeklyInsight(today, weekStart);

    await for (final _ in _completionDao.watchWeekCompletions(weekStart)) {
      yield await _computeWeeklyInsight(today, weekStart);
    }
  }

  Future<WeeklyInsight> _computeWeeklyInsight(
    DateTime today,
    DateTime weekStart,
  ) async {
    final habits = await _habitDao.getActiveHabits();
    final categories = await _categoryDao.getActiveCategories();
    final catMap = {for (final c in categories) c.id: c};

    final weekCompletions = await _completionDao.getCompletionsInRange(
      weekStart,
      today,
    );

    int totalScheduled = 0;
    int totalCompleted = 0;
    final byDay = <int, int>{}; // weekday → count

    final completionKeys = <String>{};
    for (final c in weekCompletions) {
      final key =
          '${c.habitId}_${c.completedDate.year}_${c.completedDate.month}_${c.completedDate.day}';
      completionKeys.add(key);
      byDay[c.completedDate.weekday] =
          (byDay[c.completedDate.weekday] ?? 0) + 1;
    }

    for (int i = 0; i <= today.difference(weekStart).inDays; i++) {
      final day = weekStart.add(Duration(days: i));
      for (final habit in habits) {
        if (_isHabitScheduledForDay(habit, day)) {
          totalScheduled++;
          final key =
              '${habit.id}_${day.year}_${day.month}_${day.day}';
          if (completionKeys.contains(key)) totalCompleted++;
        }
      }
    }

    final rate = totalScheduled == 0
        ? 0.0
        : (totalCompleted / totalScheduled).clamp(0.0, 1.0);

    String? bestDay;
    if (byDay.isNotEmpty) {
      final bestWeekday =
          byDay.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      const dayNames = [
        '',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      bestDay = dayNames[bestWeekday];
    }

    String? bestHabit;
    if (weekCompletions.isNotEmpty) {
      final habitCounts = <int, int>{};
      for (final c in weekCompletions) {
        habitCounts[c.habitId] = (habitCounts[c.habitId] ?? 0) + 1;
      }
      final bestId =
          habitCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      try {
        final habit = habits.firstWhere((h) => h.id == bestId);
        final cat = catMap[habit.categoryId];
        bestHabit = '${habit.emoji ?? cat?.emoji ?? '✨'} ${habit.name}';
      } catch (_) {}
    }

    return WeeklyInsight(
      message: _buildInsightMessage(
        rate: rate,
        totalCompleted: totalCompleted,
        bestDay: bestDay,
        bestHabit: bestHabit,
      ),
      weeklyCompletionRate: rate,
      mostConsistentDay: bestDay,
      bestHabitName: bestHabit,
    );
  }

  String _buildInsightMessage({
    required double rate,
    required int totalCompleted,
    String? bestDay,
    String? bestHabit,
  }) {
    final pct = (rate * 100).round();

    if (totalCompleted == 0) {
      return 'Every journey begins somewhere. '
          'This week is a fresh opportunity to build something meaningful. '
          'Start with just one habit today.';
    }

    final parts = <String>[];

    if (rate >= 0.85) {
      parts.add(
        'You completed $pct% of your habits this week — remarkable consistency.',
      );
    } else if (rate >= 0.65) {
      parts.add('$pct% completion this week — steady and building.');
    } else {
      parts.add(
        'You showed up $totalCompleted '
        'time${totalCompleted == 1 ? '' : 's'} this week — every check matters.',
      );
    }

    if (bestDay != null) {
      parts.add(
        '$bestDay seems to be your power day — you were most consistent then.',
      );
    }

    if (bestHabit != null && rate < 1.0) {
      parts.add('$bestHabit was your strongest this week.');
    } else if (rate >= 1.0) {
      parts.add('A perfect week — beautifully done. 🌟');
    }

    return parts.join(' ');
  }

  // ---------------------------------------------------------------------------
  // Streak data (single habit)
  // ---------------------------------------------------------------------------

  /// Get streak data for a specific habit.
  Future<StreakData> getHabitStreakData(int habitId) async {
    final completions = await _completionDao.getCompletionsForHabit(habitId);
    final dates = completions.map((c) => c.completedDate).toList();
    return StreakData(
      currentStreak: StreakCalculator.currentStreak(dates),
      longestStreak: StreakCalculator.longestStreak(dates),
      lastCompletedDate: dates.isNotEmpty ? dates.last : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _isHabitScheduledForDay(Habit habit, DateTime day) {
    switch (habit.frequencyType) {
      case 'daily':
        return true;
      case 'specific_days':
        if (habit.frequencyConfig == null) return true;
        try {
          final config = jsonDecode(habit.frequencyConfig!) as List;
          return config.contains(day.weekday);
        } catch (_) {
          return true;
        }
      case 'x_per_week':
        return true;
      default:
        return true;
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return HabitRepository(db.habitDao, db.completionDao, db.categoryDao);
});

final todaysHabitsProvider = StreamProvider<List<HabitWithCompletion>>((ref) {
  return ref.watch(habitRepositoryProvider).watchTodaysHabits();
});

final todaysProgressProvider = StreamProvider<DailyProgress>((ref) {
  return ref.watch(habitRepositoryProvider).watchTodaysProgress();
});

final weeklyHeatmapProvider = StreamProvider<List<DayCompletion>>((ref) {
  return ref.watch(habitRepositoryProvider).watchWeeklyHeatmap();
});

final recentCompletionsProvider =
    StreamProvider<List<CompletionWithHabit>>((ref) {
  return ref
      .watch(habitRepositoryProvider)
      .watchRecentCompletions(limit: 3);
});

final activeHabitsProvider = StreamProvider<List<Habit>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.habitDao.watchActiveHabits();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.categoryDao.watchActiveCategories();
});

// Statistics providers

final heatmapDataProvider = StreamProvider<Map<DateTime, double>>((ref) {
  return ref.watch(habitRepositoryProvider).watchHeatmapData(months: 3);
});

/// Notifier that holds the selected trend period (7, 30, or 90 days).
class TrendDaysNotifier extends Notifier<int> {
  @override
  int build() => 30;

  /// Called by the UI chip toggle to switch trend period.
  void select(int days) => state = days;
}

final trendDaysProvider =
    NotifierProvider<TrendDaysNotifier, int>(TrendDaysNotifier.new);

final completionTrendProvider = StreamProvider<List<DailyCompletion>>((ref) {
  final days = ref.watch(trendDaysProvider);
  return ref
      .watch(habitRepositoryProvider)
      .watchCompletionTrend(days: days);
});

final habitBreakdownsProvider = StreamProvider<List<HabitBreakdown>>((ref) {
  return ref.watch(habitRepositoryProvider).watchHabitBreakdowns();
});

final overallStreakProvider = StreamProvider<StreakData>((ref) {
  return ref.watch(habitRepositoryProvider).watchOverallStreak();
});

final weeklyInsightProvider = StreamProvider<WeeklyInsight>((ref) {
  return ref.watch(habitRepositoryProvider).watchWeeklyInsight();
});
