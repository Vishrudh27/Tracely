// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reflection_dao.dart';

// ignore_for_file: type=lint
mixin _$ReflectionDaoMixin on DatabaseAccessor<AppDatabase> {
  $DailyReflectionsTable get dailyReflections =>
      attachedDatabase.dailyReflections;
  $CategoriesTable get categories => attachedDatabase.categories;
  $HabitsTable get habits => attachedDatabase.habits;
  $HabitReflectionsTable get habitReflections =>
      attachedDatabase.habitReflections;
  ReflectionDaoManager get managers => ReflectionDaoManager(this);
}

class ReflectionDaoManager {
  final _$ReflectionDaoMixin _db;
  ReflectionDaoManager(this._db);
  $$DailyReflectionsTableTableManager get dailyReflections =>
      $$DailyReflectionsTableTableManager(
        _db.attachedDatabase,
        _db.dailyReflections,
      );
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db.attachedDatabase, _db.habits);
  $$HabitReflectionsTableTableManager get habitReflections =>
      $$HabitReflectionsTableTableManager(
        _db.attachedDatabase,
        _db.habitReflections,
      );
}
