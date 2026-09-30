import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';

/// Regression test for the v3→v4 migration: the 4 built-in categories
/// Stitch specifies (Health/Mind/Fitness/Learning) get re-colored on
/// upgrade, matched by name AND isBuiltIn so a same-named custom category
/// is never touched.
void main() {
  test('a fresh install seeds the new Stitch colors directly', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final categories = await db.select(db.categories).get();
    final health = categories.firstWhere((c) => c.name == 'Health');
    final mind = categories.firstWhere((c) => c.name == 'Mind');
    final fitness = categories.firstWhere((c) => c.name == 'Fitness');
    final learning = categories.firstWhere((c) => c.name == 'Learning');

    expect(health.colorValue, 0xFF5A7233);
    expect(mind.colorValue, 0xFF6B5B8C);
    expect(fitness.colorValue, 0xFFAC5E2D);
    expect(learning.colorValue, 0xFF3F6480);
    await db.close();
  });

  test('upgrading from v3 re-colors built-in categories but leaves a '
      'same-named custom one alone', () async {
    final file = File(
      '${Directory.systemTemp.path}/tracely_migration_test_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    // Stand up a v4 database (today's schema — no column changes since v3,
    // only this migration's data change), then hand-roll it back to "v3
    // with the old colors" so reopening triggers the real onUpgrade path.
    var db = AppDatabase.forTesting(NativeDatabase(file));
    final builtInHealthId = (await db.select(db.categories).get())
        .firstWhere((c) => c.name == 'Health')
        .id;

    await db.update(db.categories).replace(
          CategoriesCompanion(
            id: Value(builtInHealthId),
            name: const Value('Health'),
            emoji: const Value('favorite'),
            colorValue: const Value(0xFF65A30D), // the pre-migration color
            sortOrder: const Value(0),
            isBuiltIn: const Value(true),
          ),
        );

    final customHealthId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: 'Health', // same name, but user-made
            emoji: 'favorite',
            colorValue: 0xFF112233, // an arbitrary color the user picked
            isBuiltIn: const Value(false),
          ),
        );

    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    // Reopen the same file — Drift reads user_version=3, sees the class's
    // schemaVersion=4, and runs the real onUpgrade(from: 3, to: 4).
    db = AppDatabase.forTesting(NativeDatabase(file));
    final rows = await db.select(db.categories).get();

    final builtIn = rows.firstWhere((c) => c.id == builtInHealthId);
    final custom = rows.firstWhere((c) => c.id == customHealthId);

    expect(builtIn.colorValue, 0xFF5A7233, reason: 'built-in Health re-colored');
    expect(custom.colorValue, 0xFF112233, reason: 'custom Health untouched');

    await db.close();
  });
}
