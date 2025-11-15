// Sqflite ProductRepository with structured dev logs for create/update/delete/find/list operations.

import 'dart:convert';
import 'dart:developer' as dev;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:jaayko/infrastructure/db/app_database.dart';
import 'package:jaayko/domain/products/entities/product.dart';
import 'package:jaayko/domain/products/repositories/product_repository.dart';
import 'package:jaayko/sync/infrastructure/change_tracked_exec.dart';

class ProductRepositorySqflite implements ProductRepository {
  final AppDatabase _db;
  ProductRepositorySqflite(this._db);

  String _nowUtcIso() => DateTime.now().toUtc().toIso8601String();

  void _log(String op, Map<String, Object?> data) {
    try {
      final payload = {'op': op, 'at': _nowUtcIso(), ...data};
      dev.log(
        const JsonEncoder.withIndent('  ').convert(payload),
        name: 'ProductRepositorySqflite',
      );
    } catch (_) {
      dev.log('$op ${data.toString()}', name: 'ProductRepositorySqflite');
    }
  }

  String? _trimOrNull(String? s) {
    if (s == null) return null;
    final v = s.trim();
    return v.isEmpty ? null : v;
  }

  int _nz(int? v) => (v == null || v < 0) ? 0 : v;

  Map<String, Object?> _stripNulls(Map<String, Object?> m) {
    final out = <String, Object?>{};
    m.forEach((k, v) {
      if (v != null) out[k] = v;
    });
    return out;
  }

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
      version: p.version + 1,
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
      await txn.insertTracked('stock_level', {
        'id': id,
        'productVariantId': productId,
        'companyId': companyId,
        'stockOnHand': 0,
        'stockAllocated': 0,
        'createdAt': now,
        'updatedAt': now,
        'version': 0,
      }, operation: 'INSERT');
    }
  }

  @override
  Future<Product> create(Product product) async {
    final p = _prepCreate(product);
    _log('CREATE.begin', {
      'id': p.id,
      'code': p.code,
      'name': p.name,
      'quantity': p.quantity,
    });
    await _db.tx((txn) async {
      await txn.insertTracked('product', p.toMap(), operation: 'INSERT');
      await _ensureStockLevels(txn, p.id);
    });
    _log('CREATE.done', {'id': p.id});
    return p;
  }

  @override
  Future<void> update(Product product) async {
    final p = _prepUpdate(product);
    final full = _stripNulls(p.toMap())..remove('version');
    _log('UPDATE.begin', {
      'id': p.id,
      'quantity': p.quantity,
      'hasSold': p.hasSold,
      'hasPrice': p.hasPrice,
      'defaultPrice': p.defaultPrice,
      'purchasePrice': p.purchasePrice,
      'statuses': p.statuses,
    });
    await _db.tx((txn) async {
      await txn.updateTracked(
        'product',
        full,
        where: 'id = ?',
        whereArgs: [p.id],
        entityId: p.id,
        operation: 'UPDATE',
      );
    });
    _log('UPDATE.done', {'id': p.id});
  }

  @override
  Future<void> softDelete(String id) async {
    _log('SOFT_DELETE.begin', {'id': id});
    await _db.tx((txn) async {
      await txn.softDeleteTracked('product', entityId: id);
    });
    _log('SOFT_DELETE.done', {'id': id});
  }

  @override
  Future<Product?> findById(String id) async {
    _log('FIND_BY_ID.begin', {'id': id});
    final r = await _db.db.query(
      'product',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    final res = r.isEmpty ? null : _from(r.first);
    _log('FIND_BY_ID.done', {'id': id, 'found': res != null});
    return res;
  }

  @override
  Future<Product?> findByCode(String code) async {
    _log('FIND_BY_CODE.begin', {'code': code});
    final r = await _db.db.query(
      'product',
      where: 'code = ? AND deletedAt IS NULL',
      whereArgs: [code],
      limit: 1,
    );
    final res = r.isEmpty ? null : _from(r.first);
    _log('FIND_BY_CODE.done', {'code': code, 'found': res != null});
    return res;
  }

  @override
  Future<List<Product>> findAllActive() async {
    _log('LIST_ACTIVE.begin', {});
    final rows = await _db.db.query(
      'product',
      where: 'deletedAt IS NULL',
      orderBy:
          'updatedAt DESC, COALESCE(name, code) COLLATE NOCASE ASC, code COLLATE NOCASE ASC',
    );
    final list = rows.map(_from).toList();
    _log('LIST_ACTIVE.done', {'count': list.length});
    return list;
  }

  @override
  Future<List<Product>> searchActive(String query, {int limit = 200}) async {
    _log('SEARCH_ACTIVE.begin', {'query': query, 'limit': limit});
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
    final list = rows.map(_from).toList();
    _log('SEARCH_ACTIVE.done', {'count': list.length});
    return list;
  }
}
