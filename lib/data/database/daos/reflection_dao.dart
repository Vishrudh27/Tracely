import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/daily_reflections_table.dart';
import '../tables/habit_reflections_table.dart';

part 'reflection_dao.g.dart';

/// Data Access Object for DailyReflections and HabitReflections tables.
///
/// DailyReflections — one record per day, tracks morning ritual state.
/// HabitReflections — one record per missed-habit per day, tracks WHY.
@DriftAccessor(tables: [DailyReflections, HabitReflections])
class ReflectionDao extends DatabaseAccessor<AppDatabase>
    with _$ReflectionDaoMixin {
  ReflectionDao(super.db);

  // ---------------------------------------------------------------------------
  // DailyReflections reads
  // ---------------------------------------------------------------------------

  /// Get today's reflection record, if it exists.
  Future<DailyReflection?> getTodaysReflection() {
    final today = _normalizeDate(DateTime.now());
    return (select(dailyReflections)
          ..where((r) => r.reflectionDate.equals(today)))
        .getSingleOrNull();
  }

  /// Get the reflection for a specific date.
  Future<DailyReflection?> getReflectionForDate(DateTime date) {
    final normalized = _normalizeDate(date);
    return (select(dailyReflections)
          ..where((r) => r.reflectionDate.equals(normalized)))
        .getSingleOrNull();
  }

  /// Watch recent reflections for Statistics (newest first).
  Stream<List<DailyReflection>> watchRecentReflections({int limit = 30}) {
    return (select(dailyReflections)
          ..orderBy([(r) => OrderingTerm.desc(r.reflectionDate)])
          ..limit(limit))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // DailyReflections writes
  // ---------------------------------------------------------------------------

  /// Record or update today's reflection.
  ///
  /// Uses insertOnConflictUpdate to handle the unique constraint on reflectionDate.
  Future<void> recordReflection({
    required String? shownQuote,
    int? moodRating,
    String? note,
  }) async {
    final today = _normalizeDate(DateTime.now());
    await into(dailyReflections).insertOnConflictUpdate(
      DailyReflectionsCompanion.insert(
        reflectionDate: today,
        shownQuote: Value(shownQuote),
        moodRating: Value(moodRating),
        note: Value(note),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HabitReflections reads
  // ---------------------------------------------------------------------------

  /// Check if this exact reason is already recorded for a habit on a date.
  ///
  /// Reasons are stored one row per reason, so the identity of a reflection is
  /// (habit, date, reason) — not (habit, date).
  Future<bool> hasHabitReflection(
    int habitId,
    DateTime date,
    String reason,
  ) async {
    final normalized = _normalizeDate(date);
    final rows = await (select(habitReflections)
          ..where(
            (r) =>
                r.habitId.equals(habitId) &
                r.missedDate.equals(normalized) &
                r.reason.equals(reason),
          )
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  /// Watch the most frequently selected reasons across all habit reflections.
  ///
  /// Returns up to [limit] reasons sorted by frequency (most common first).
  /// Used by MostCommonReasonsCard in the Statistics screen.
  Stream<List<ReasonFrequency>> watchMostCommonReasons({int limit = 5}) {
    // Raw count-group query using Drift's expression API
    final reasonCount = habitReflections.reason;
    final count = habitReflections.id.count();

    final query = db.selectOnly(habitReflections)
      ..addColumns([reasonCount, count])
      ..groupBy([reasonCount])
      ..orderBy([OrderingTerm.desc(count)])
      ..limit(limit);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ReasonFrequency(
          reason: row.read(reasonCount) ?? '',
          count: row.read(count) ?? 0,
        );
      }).toList();
    });
  }

  /// Watch the most frequently selected reasons for one habit's missed days.
  ///
  /// Same shape as [watchMostCommonReasons], scoped to a single habit — used
  /// by Habit Detail's "Why it slipped" section.
  Stream<List<ReasonFrequency>> watchMostCommonReasonsForHabit(
    int habitId, {
    int limit = 3,
  }) {
    final reasonCount = habitReflections.reason;
    final count = habitReflections.id.count();

    final query = db.selectOnly(habitReflections)
      ..addColumns([reasonCount, count])
      ..where(habitReflections.habitId.equals(habitId))
      ..groupBy([reasonCount])
      ..orderBy([OrderingTerm.desc(count)])
      ..limit(limit);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ReasonFrequency(
          reason: row.read(reasonCount) ?? '',
          count: row.read(count) ?? 0,
        );
      }).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // HabitReflections writes
  // ---------------------------------------------------------------------------

  /// Persist a single Pause & Reflect reason for a missed habit.
  ///
  /// One row per reason, so [watchMostCommonReasons] can group on an atomic
  /// key. Storing several reasons joined into one string made every distinct
  /// combination count as its own reason.
  ///
  /// Silently skips if this habit+date+reason is already recorded (idempotent
  /// — prevents duplicates from double-taps).
  Future<void> createHabitReflection({
    required int habitId,
    required DateTime missedDate,
    required String reason,
    String? followUpAnswer,
  }) async {
    final normalized = _normalizeDate(missedDate);
    if (await hasHabitReflection(habitId, normalized, reason)) return;

    await into(habitReflections).insert(
      HabitReflectionsCompanion.insert(
        habitId: habitId,
        missedDate: normalized,
        reason: reason,
        followUpAnswer: Value(followUpAnswer),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Normalize a DateTime to midnight local time for date-level comparisons.
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

/// A reason + how many times it was selected across all habit reflections.
///
/// Used as the return type for [ReflectionDao.watchMostCommonReasons].
class ReasonFrequency {
  const ReasonFrequency({required this.reason, required this.count});

  /// The reason key e.g. 'energy', 'time', 'forgot', 'motivation',
  /// 'environment', 'other'.
  final String reason;

  /// How many times this reason has been selected.
  final int count;
}
