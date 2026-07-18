// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_dao.dart';

// ignore_for_file: type=lint
mixin _$CompletionDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $HabitsTable get habits => attachedDatabase.habits;
  $HabitCompletionsTable get habitCompletions =>
      attachedDatabase.habitCompletions;
  CompletionDaoManager get managers => CompletionDaoManager(this);
}

class CompletionDaoManager {
  final _$CompletionDaoMixin _db;
  CompletionDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db.attachedDatabase, _db.habits);
  $$HabitCompletionsTableTableManager get habitCompletions =>
      $$HabitCompletionsTableTableManager(
        _db.attachedDatabase,
        _db.habitCompletions,
      );
}
