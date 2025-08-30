// lib/infrastructure/products/product_repository_sqflite.dart
//
// Sqflite product repository using ChangeTrackedExec helpers:
// - Normalization + UTC timestamps
// - insertTracked / updateTracked / softDeleteTracked -> auto isDirty, updatedAt,
//   version bump (on update/delete), and change_log upsert
// - Automatic stock_level bootstrap per company (also via insertTracked)
// - UpdatedAt-desc ordering for lists
//
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/products/repositories/product_repository.dart';

import 'package:money_pulse/sync/infrastructure/change_tracked_exec.dart';

class ProductRepositorySqflite implements ProductRepository {
  final AppDatabase _db;
  ProductRepositorySqflite(this._db);

  String _nowUtcIso() => DateTime.now().toUtc().toIso8601String();

  String? _trimOrNull(String? s) {
    if (s == null) return null;
    final v = s.trim();
    return v.isEmpty ? null : v;
  }

  int _nz(int? v) => (v == null || v < 0) ? 0 : v;

  Product _normalize(Product p) {
    final nameTrimmed = _trimOrNull(p.name);
    final codeTrimmed = _trimOrNull(p.code);
    final descTrimmed = _trimOrNull(p.description);
    final barcodeTrimmed = _trimOrNull(p.barcode);
    final unitIdTrimmed = _trimOrNull(p.unitId);
    final categoryIdTrimmed = _trimOrNull(p.categoryId);
    final statusesTrimmed = _trimOrNull(p.statuses);

    final defPrice = _nz(p.defaultPrice);
    final purch = _nz(p.purchasePrice) <= 0 ? defPrice : _nz(p.purchasePrice);

    return p.copyWith(
      name: nameTrimmed ?? 'No name',
      code: codeTrimmed,
      description: descTrimmed,
      barcode: barcodeTrimmed,
      unitId: unitIdTrimmed,
      categoryId: categoryIdTrimmed,
      statuses: statusesTrimmed,
      defaultPrice: defPrice,
      purchasePrice: purch,
    );
  }

  Product _prepCreate(Product p) {
    final n = _normalize(p);
    final now = DateTime.now().toUtc();
    return n.copyWith(createdAt: now, updatedAt: now, version: 0, isDirty: 1);
  }

  Product _prepUpdate(Product p) {
    final n = _normalize(p);
    return n.copyWith(
      updatedAt: DateTime.now().toUtc(),
      version:
          p.version + 1, // updateTracked will bump again; we’ll drop it in map
      isDirty: 1,
    );
  }

  Product _from(Map<String, Object?> m) => Product.fromMap(m);

  Future<void> _ensureStockLevels(Transaction txn, String productId) async {
    final companies = await txn.rawQuery(
      'SELECT id FROM company WHERE deletedAt IS NULL',
    );
    final now = _nowUtcIso();

    for (final c in companies) {
      final companyId = (c['id'] as String?) ?? '';
      if (companyId.isEmpty) continue;

      final exists = await txn.rawQuery(
        'SELECT id FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1',
        [productId, companyId],
      );
      if (exists.isNotEmpty) continue;

      final id = const Uuid().v4();
      // insertTracked will stamp timestamps/isDirty and upsert change_log
      await txn.insertTracked(
        'stock_level',
        {
          'id': id,
          'productVariantId': productId,
          'companyId': companyId,
          'stockOnHand': 0,
          'stockAllocated': 0,
          'createdAt': now,
          'updatedAt': now,
          'version': 0,
        },
        operation: 'INSERT',
        // If your stock_level table has an 'account' column, ChangeTrackedExec
        // will auto-stamp it; otherwise it’s a no-op.
      );
    }
  }

  // ---------- CRUD ----------

  @override
  Future<Product> create(Product product) async {
    final p = _prepCreate(product);
    await _db.tx((txn) async {
      // Product insert (auto-stamp + changelog)
      await txn.insertTracked('product', p.toMap(), operation: 'INSERT');

      // Bootstrap per-company stock levels (each via insertTracked)
      await _ensureStockLevels(txn, p.id);
    });
    return p;
  }

  @override
  Future<void> update(Product product) async {
    final p = _prepUpdate(product);
    await _db.tx((txn) async {
      final map = p.toMap()
        ..remove('version'); // updateTracked will version++ for us
      await txn.updateTracked(
        'product',
        map,
        where: 'id = ?',
        whereArgs: [p.id],
        entityId: p.id,
        operation: 'UPDATE',
      );
    });
  }

  @override
  Future<void> softDelete(String id) async {
    await _db.tx((txn) async {
      await txn.softDeleteTracked('product', entityId: id);
    });
  }

  // ---------- Queries ----------

  @override
  Future<Product?> findById(String id) async {
    final r = await _db.db.query(
      'product',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return _from(r.first);
  }

  @override
  Future<Product?> findByCode(String code) async {
    final r = await _db.db.query(
      'product',
      where: 'code = ? AND deletedAt IS NULL',
      whereArgs: [code],
      limit: 1,
    );
    if (r.isEmpty) return null;
    return _from(r.first);
  }

  @override
  Future<List<Product>> findAllActive() async {
    final rows = await _db.db.query(
      'product',
      where: 'deletedAt IS NULL',
      orderBy:
          'updatedAt DESC, COALESCE(name, code) COLLATE NOCASE ASC, code COLLATE NOCASE ASC',
    );
    return rows.map(_from).toList();
  }

  @override
  Future<List<Product>> searchActive(String query, {int limit = 200}) async {
    final q = '%${query.trim().toLowerCase()}%';
    final rows = await _db.db.rawQuery(
      '''
      SELECT * FROM product
      WHERE deletedAt IS NULL
        AND lower(
          COALESCE(name,'') || ' ' ||
          COALESCE(code,'') || ' ' ||
          COALESCE(barcode,'') || ' ' ||
          COALESCE(statuses,'')
        ) LIKE ?
      ORDER BY updatedAt DESC,
               COALESCE(name, code) COLLATE NOCASE ASC,
               code COLLATE NOCASE ASC
      LIMIT ?
      ''',
      [q, limit],
    );
    return rows.map(_from).toList();
  }
}
