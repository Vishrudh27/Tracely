import 'package:drift/drift.dart';

/// Drift table for daily reflection records.
///
/// One record per calendar day. Records which quote was shown,
/// optional mood rating, and optional free-text notes.
/// Used by the ReflectionScreen to persist state and by Statistics
/// to build the user's reflection history.
class DailyReflections extends Table {
  /// Auto-incrementing primary key.
  IntColumn get id => integer().autoIncrement()();

  /// The calendar date this reflection is for (midnight-normalized).
  DateTimeColumn get reflectionDate => dateTime()();

  /// The quote text that was displayed on the ReflectionScreen.
  /// Stored so Statistics can show "reflections over time".
  TextColumn get shownQuote => text().nullable()();

  /// Optional mood rating for the day.
  /// Scale: 1=rough, 2=okay, 3=good, 4=great, 5=amazing.
  /// Null if the user did not set a mood.
  IntColumn get moodRating => integer().nullable()();

  /// Optional free-text note from the user.
  TextColumn get note => text().nullable()();

  /// When this reflection record was created.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Enforce one reflection per calendar day.
  @override
  List<Set<Column>> get uniqueKeys => [
        {reflectionDate},
      ];
}
