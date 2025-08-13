/// Repository that persists products and ensures a stock_level row is created per active company on creation.
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/products/repositories/product_repository.dart';

class ProductRepositorySqflite implements ProductRepository {
  final AppDatabase _db;
  ProductRepositorySqflite(this._db);

  String _now() => DateTime.now().toIso8601String();

  Product _prepCreate(Product p) => p.copyWith(
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    version: 0,
    isDirty: 1,
  );

  Product _prepUpdate(Product p) =>
      p.copyWith(updatedAt: DateTime.now(), version: p.version + 1, isDirty: 1);

  Product _from(Map<String, Object?> m) => Product.fromMap(m);

  Future<void> _ensureStockLevels(Transaction txn, String productId) async {
    final companies = await txn.rawQuery(
      "SELECT id FROM company WHERE deletedAt IS NULL",
    );
    final now = _now();
    for (final c in companies) {
      final companyId = (c['id'] as String?) ?? '';
      if (companyId.isEmpty) continue;
      final exists = await txn.rawQuery(
        "SELECT id FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1",
        [productId, companyId],
      );
      if (exists.isNotEmpty) continue;
      await txn.insert('stock_level', {
        'productVariantId': productId,
        'companyId': companyId,
        'stockOnHand': 0,
        'stockAllocated': 0,
        'createdAt': now,
        'updatedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  @override
  Future<Product> create(Product product) async {
    final p = _prepCreate(product);
    await _db.tx((txn) async {
      await txn.insert(
        'product',
        p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await _ensureStockLevels(txn, p.id);

      final idLog = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'product', p.id, 'INSERT', null, 'PENDING', _now(), _now()],
      );
    });
    return p;
  }

  @override
  Future<void> update(Product product) async {
    final p = _prepUpdate(product);
    await _db.tx((txn) async {
      await txn.update(
        'product',
        p.toMap(),
        where: 'id = ?',
        whereArgs: [p.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      final idLog = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'product', p.id, 'UPDATE', null, 'PENDING', _now(), _now()],
      );
    });
  }

  @override
  Future<void> softDelete(String id) async {
    final now = _now();
    await _db.tx((txn) async {
      await txn.rawUpdate(
        'UPDATE product SET deletedAt=?, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
        [now, now, id],
      );
      final idLog = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'product', id, 'DELETE', null, 'PENDING', now, now],
      );
    });
  }

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
      orderBy: 'name COLLATE NOCASE ASC, code COLLATE NOCASE ASC',
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
        AND lower(coalesce(name,'') || ' ' || coalesce(code,'') || ' ' || coalesce(barcode,'')) LIKE ?
      ORDER BY name COLLATE NOCASE ASC, code COLLATE NOCASE ASC
      LIMIT ?
      ''',
      [q, limit],
    );
    return rows.map((e) => _from(e)).toList();
  }
}
