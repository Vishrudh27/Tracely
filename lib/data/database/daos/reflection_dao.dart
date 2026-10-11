import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/daily_reflections_table.dart';
import '../tables/habit_reflections_table.dart';

part 'reflection_dao.g.dart';

/// Data Access Object for DailyReflections and HabitReflections tables.
///
/// DailyReflections — one record per day, tracks morning ritual state.
/// HabitReflections — one record per day (Pause & Reflect v2), tracks missed habits and reasons.
@DriftAccessor(tables: [DailyReflections, HabitReflections])
class ReflectionDao extends DatabaseAccessor<AppDatabase>
    with _$ReflectionDaoMixin {
  ReflectionDao(super.db);

  // ---------------------------------------------------------------------------
  // DailyReflections reads & writes
  // ---------------------------------------------------------------------------

  /// Get today's daily reflection record, if it exists.
  Future<DailyReflection?> getTodaysReflection() {
    final today = _normalizeDate(DateTime.now());
    return (select(dailyReflections)
          ..where((r) => r.reflectionDate.equals(today)))
        .getSingleOrNull();
  }

  /// Get the daily reflection for a specific date.
  Future<DailyReflection?> getDailyReflectionForDate(DateTime date) {
    final normalized = _normalizeDate(date);
    return (select(dailyReflections)
          ..where((r) => r.reflectionDate.equals(normalized)))
        .getSingleOrNull();
  }

  /// Watch recent daily reflections for Statistics (newest first).
  Stream<List<DailyReflection>> watchRecentReflections({int limit = 30}) {
    return (select(dailyReflections)
          ..orderBy([(r) => OrderingTerm.desc(r.reflectionDate)])
          ..limit(limit))
        .watch();
  }

  /// Record or update today's daily reflection (morning ritual).
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
  // HabitReflections (Pause & Reflect v2 — One row per day)
  // ---------------------------------------------------------------------------

  /// Get the missed-day reflection for a specific date.
  Future<HabitReflection?> getReflectionForDate(DateTime date) {
    final normalized = _normalizeDate(date);
    return (select(habitReflections)
          ..where((r) => r.reflectionDate.equals(normalized)))
        .getSingleOrNull();
  }

  /// Watch the missed-day reflection for a specific date.
  Stream<HabitReflection?> watchReflectionForDate(DateTime date) {
    final normalized = _normalizeDate(date);
    return (select(habitReflections)
          ..where((r) => r.reflectionDate.equals(normalized)))
        .watchSingleOrNull();
  }

  /// Insert or update the reflection for [reflectionDate].
  ///
  /// Enforces one row per calendar day via ON CONFLICT(reflection_date).
  /// Allows seamless editing and updating of existing reflections.
  Future<void> upsertReflection({
    required DateTime reflectionDate,
    required List<String> reasonKeys,
    String? customText,
    String? followUpReasonKey,
    String? followUpAnswer,
    required List<int> missedHabitIds,
  }) async {
    final normalized = _normalizeDate(reflectionDate);
    final now = DateTime.now();

    await into(habitReflections).insert(
      HabitReflectionsCompanion.insert(
        reflectionDate: normalized,
        reasonKeys: jsonEncode(reasonKeys),
        customText: Value(customText),
        followUpReasonKey: Value(followUpReasonKey),
        followUpAnswer: Value(followUpAnswer),
        missedHabitIds: jsonEncode(missedHabitIds),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
      onConflict: DoUpdate(
        (old) => HabitReflectionsCompanion(
          reasonKeys: Value(jsonEncode(reasonKeys)),
          customText: Value(customText),
          followUpReasonKey: Value(followUpReasonKey),
          followUpAnswer: Value(followUpAnswer),
          missedHabitIds: Value(jsonEncode(missedHabitIds)),
          updatedAt: Value(now),
        ),
        target: [habitReflections.reflectionDate],
      ),
    );
  }

  /// Delete the habit reflection for [reflectionDate], resetting it to an unlogged state.
  Future<int> deleteReflectionForDate(DateTime reflectionDate) {
    final normalized = _normalizeDate(reflectionDate);
    return (delete(habitReflections)
          ..where((r) => r.reflectionDate.equals(normalized)))
        .go();
  }

  /// Retrieve all habit reflections within a date range (inclusive), newest first.
  Future<List<HabitReflection>> getReflectionsInRange(
    DateTime start,
    DateTime end,
  ) {
    final normStart = _normalizeDate(start);
    final normEnd = _normalizeDate(end);
    return (select(habitReflections)
          ..where(
            (r) =>
                r.reflectionDate.isBiggerOrEqualValue(normStart) &
                r.reflectionDate.isSmallerOrEqualValue(normEnd),
          )
          ..orderBy([(r) => OrderingTerm.desc(r.reflectionDate)]))
        .get();
  }

  /// Watch all habit reflections within a date range (inclusive), newest first.
  Stream<List<HabitReflection>> watchReflectionsInRange(
    DateTime start,
    DateTime end,
  ) {
    final normStart = _normalizeDate(start);
    final normEnd = _normalizeDate(end);
    return (select(habitReflections)
          ..where(
            (r) =>
                r.reflectionDate.isBiggerOrEqualValue(normStart) &
                r.reflectionDate.isSmallerOrEqualValue(normEnd),
          )
          ..orderBy([(r) => OrderingTerm.desc(r.reflectionDate)]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // Reason Aggregations (MostCommonReasonsCard data source)
  // ---------------------------------------------------------------------------

  /// Watch the most frequently selected reasons across habit reflections (last [days] days).
  ///
  /// Reads rows in range, decodes JSON reasonKeys in Dart, and tallies frequency.
  /// Output matches previous schema: List of [ReasonFrequency] sorted desc.
  Stream<List<ReasonFrequency>> watchMostCommonReasons({
    int limit = 5,
    int days = 30,
  }) {
    final start = DateTime.now().subtract(Duration(days: days));
    final normalizedStart = _normalizeDate(start);

    final query = select(habitReflections)
      ..where((r) => r.reflectionDate.isBiggerOrEqualValue(normalizedStart))
      ..orderBy([(r) => OrderingTerm.desc(r.reflectionDate)]);

    return query.watch().map((rows) {
      final counts = <String, int>{};
      for (final row in rows) {
        try {
          final keys = (jsonDecode(row.reasonKeys) as List).cast<String>();
          for (final k in keys) {
            if (k.isNotEmpty) {
              counts[k] = (counts[k] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }

      final list = counts.entries
          .map((e) => ReasonFrequency(reason: e.key, count: e.value))
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      return list.take(limit).toList();
    });
  }

  /// Watch reasons specifically attributed to missed days for [habitId].
  Stream<List<ReasonFrequency>> watchMostCommonReasonsForHabit(
    int habitId, {
    int limit = 3,
    int days = 30,
  }) {
    final start = DateTime.now().subtract(Duration(days: days));
    final normalizedStart = _normalizeDate(start);

    final query = select(habitReflections)
      ..where((r) => r.reflectionDate.isBiggerOrEqualValue(normalizedStart))
      ..orderBy([(r) => OrderingTerm.desc(r.reflectionDate)]);

    return query.watch().map((rows) {
      final counts = <String, int>{};
      for (final row in rows) {
        try {
          final habits = (jsonDecode(row.missedHabitIds) as List).cast<int>();
          if (!habits.contains(habitId)) continue;

          final keys = (jsonDecode(row.reasonKeys) as List).cast<String>();
          for (final k in keys) {
            if (k.isNotEmpty) {
              counts[k] = (counts[k] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }

      final list = counts.entries
          .map((e) => ReasonFrequency(reason: e.key, count: e.value))
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      return list.take(limit).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Backward-compatibility helpers
  // ---------------------------------------------------------------------------

  /// Habits that already have a reflection recorded for [date].
  Future<Set<int>> getReflectedHabitIds(DateTime date) async {
    final reflection = await getReflectionForDate(date);
    if (reflection == null) return {};
    try {
      final list = (jsonDecode(reflection.missedHabitIds) as List).cast<int>();
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  /// Check if a reason is already recorded for a habit on [date].
  Future<bool> hasHabitReflection(
    int habitId,
    DateTime date,
    String reason,
  ) async {
    final reflection = await getReflectionForDate(date);
    if (reflection == null) return false;
    try {
      final keys = (jsonDecode(reflection.reasonKeys) as List).cast<String>();
      final habits = (jsonDecode(reflection.missedHabitIds) as List).cast<int>();
      return keys.contains(reason) && habits.contains(habitId);
    } catch (_) {
      return false;
    }
  }

  /// Voice command / legacy adapter to record a single habit miss.
  Future<void> createHabitReflection({
    required int habitId,
    required DateTime missedDate,
    required String reason,
    String? followUpAnswer,
  }) async {
    final existing = await getReflectionForDate(missedDate);
    final habitIds = <int>{habitId};
    final reasons = <String>{reason};

    if (existing != null) {
      try {
        final decodedHabits =
            (jsonDecode(existing.missedHabitIds) as List).cast<int>();
        habitIds.addAll(decodedHabits);
        final decodedReasons =
            (jsonDecode(existing.reasonKeys) as List).cast<String>();
        reasons.addAll(decodedReasons);
      } catch (_) {}
    }

    await upsertReflection(
      reflectionDate: missedDate,
      reasonKeys: reasons.take(2).toList(),
      missedHabitIds: habitIds.toList(),
      followUpReasonKey: existing?.followUpReasonKey,
      followUpAnswer: followUpAnswer ?? existing?.followUpAnswer,
      customText: existing?.customText,
    );
  }

  /// Removes a reason recorded for [missedDate] — Undo helper for voice commands.
  Future<void> removeHabitReflection(
    int habitId,
    DateTime missedDate,
    String reason,
  ) async {
    final existing = await getReflectionForDate(missedDate);
    if (existing == null) return;

    try {
      final decodedReasons =
          (jsonDecode(existing.reasonKeys) as List).cast<String>().toSet();
      decodedReasons.remove(reason);

      final decodedHabits =
          (jsonDecode(existing.missedHabitIds) as List).cast<int>().toSet();

      if (decodedReasons.isEmpty && (existing.customText?.isEmpty ?? true)) {
        await (delete(habitReflections)
              ..where((r) => r.reflectionDate.equals(existing.reflectionDate)))
            .go();
      } else {
        await upsertReflection(
          reflectionDate: missedDate,
          reasonKeys: decodedReasons.toList(),
          missedHabitIds: decodedHabits.toList(),
          followUpReasonKey: existing.followUpReasonKey,
          followUpAnswer: existing.followUpAnswer,
          customText: existing.customText,
        );
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

/// A reason + how many times it was selected across all habit reflections.
class ReasonFrequency {
  const ReasonFrequency({required this.reason, required this.count});

  final String reason;
  final int count;
}
