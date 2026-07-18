import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

/// Provides the single [AppDatabase] instance as a singleton.
///
/// The database is created once and shared across the entire app.
/// All DAO providers read from this provider.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Dispose the database when the provider is destroyed.
  ref.onDispose(db.close);
  return db;
});
