import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/daily_reflections_table.dart';

part 'reflection_dao.g.dart';

/// Data Access Object for the DailyReflections table.
@DriftAccessor(tables: [DailyReflections])
class ReflectionDao extends DatabaseAccessor<AppDatabase>
    with _$ReflectionDaoMixin {
  ReflectionDao(super.db);

  // ---------------------------------------------------------------------------
  // Reads
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
  // Writes
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
  // Helpers
  // ---------------------------------------------------------------------------

  /// Normalize a DateTime to midnight local time for date-level comparisons.
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
