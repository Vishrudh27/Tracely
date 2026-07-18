// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_dao.dart';

// ignore_for_file: type=lint
mixin _$HabitDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $HabitsTable get habits => attachedDatabase.habits;
  HabitDaoManager get managers => HabitDaoManager(this);
}

class HabitDaoManager {
  final _$HabitDaoMixin _db;
  HabitDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db.attachedDatabase, _db.habits);
}
