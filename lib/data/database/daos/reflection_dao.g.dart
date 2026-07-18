// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reflection_dao.dart';

// ignore_for_file: type=lint
mixin _$ReflectionDaoMixin on DatabaseAccessor<AppDatabase> {
  $DailyReflectionsTable get dailyReflections =>
      attachedDatabase.dailyReflections;
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
}
