import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories_table.dart';

part 'category_dao.g.dart';

/// Data Access Object for the Categories table.
///
/// All category reads/writes go through this DAO — no raw SQL in repositories.
@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Watch all active (non-archived) categories, ordered by sortOrder.
  Stream<List<Category>> watchActiveCategories() {
    return (select(categories)
          ..where((c) => c.isArchived.equals(false))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .watch();
  }

  /// Get all active categories as a one-shot future.
  Future<List<Category>> getActiveCategories() {
    return (select(categories)
          ..where((c) => c.isArchived.equals(false))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  /// Get a single category by ID.
  Future<Category?> getCategoryById(int id) {
    return (select(categories)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Insert a new category. Returns the new row ID.
  Future<int> insertCategory(CategoriesCompanion category) {
    return into(categories).insert(category);
  }

  /// Update an existing category.
  Future<bool> updateCategory(CategoriesCompanion category) {
    return update(categories).replace(category);
  }

  /// Soft-delete a category (sets isArchived = true).
  /// Built-in categories cannot be archived.
  Future<void> archiveCategory(int id) async {
    await (update(categories)
          ..where((c) => c.id.equals(id) & c.isBuiltIn.equals(false)))
        .write(
      const CategoriesCompanion(isArchived: Value(true)),
    );
  }
}
