// Sqflite repository for categories using tracked insert/update/delete with change_log.
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';
import 'package:money_pulse/sync/infrastructure/change_tracked_exec.dart';

class CategoryRepositorySqflite implements CategoryRepository {
  final AppDatabase _db;
  CategoryRepositorySqflite(this._db);

  @override
  Future<Category> create(Category category) async {
    final c = category.copyWith(
      updatedAt: DateTime.now(),
      version: 0,
      isDirty: true,
      typeEntry: category.typeEntry.toUpperCase(),
    );

    await _db.tx((txn) async {
      await txn.insertTracked('category', c.toMap());
    });
    return c;
  }

  @override
  Future<void> update(Category category) async {
    final c = category.copyWith(
      updatedAt: DateTime.now(),
      version: category.version + 1,
      isDirty: true,
      typeEntry: category.typeEntry.toUpperCase(),
    );

    await _db.tx((txn) async {
      await txn.updateTracked(
        'category',
        c.toMap(),
        where: 'id=?',
        whereArgs: [c.id],
        entityId: c.id,
      );
    });
  }

  @override
  Future<void> softDelete(String id) async {
    await _db.tx((txn) async {
      await txn.softDeleteTracked('category', entityId: id);
    });
  }

  @override
  Future<Category?> findById(String id) async {
    final r = await _db.db.query(
      'category',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return Category.fromMap(r.first);
  }

  @override
  Future<Category?> findByCode(String code) async {
    final r = await _db.db.query(
      'category',
      where: 'code=? AND deletedAt IS NULL',
      whereArgs: [code],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return Category.fromMap(r.first);
  }

  @override
  Future<List<Category>> findAllActive() async {
    final rows = await _db.db.query(
      'category',
      where: 'deletedAt IS NULL',
      orderBy: 'updatedAt DESC, code ASC',
    );
    return rows.map(Category.fromMap).toList();
  }
}
