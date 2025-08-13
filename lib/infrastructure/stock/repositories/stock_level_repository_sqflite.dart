// Sqflite StockLevelRepository wired through AppDatabase

import 'package:sqflite/sqflite.dart';
import '../../../infrastructure/db/app_database.dart';
import '../../../domain/stock/entities/stock_level.dart';
import '../../../domain/stock/repositories/stock_level_repository.dart';

class StockLevelRepositorySqflite implements StockLevelRepository {
  final AppDatabase app;
  late final Database db;

  StockLevelRepositorySqflite(this.app) {
    db = app.db;
  }

  @override
  Future<List<StockLevelRow>> search({String query = ''}) async {
    final q = query.trim();
    final like = '%$q%';
    final rows = await db.rawQuery(
      '''
      SELECT sl.id,
             sl.stockOnHand,
             sl.stockAllocated,
             sl.updatedAt,
             COALESCE(pv.name, pv.code, 'Variant #'||sl.productVariantId) AS productLabel,
             COALESCE(c.name, c.code, sl.companyId) AS companyLabel
      FROM stock_level sl
      LEFT JOIN product pv ON pv.id = sl.productVariantId
      LEFT JOIN company c ON c.id = sl.companyId
      WHERE (? = '' 
         OR pv.name LIKE ? OR pv.code LIKE ?
         OR c.name LIKE ? OR c.code LIKE ?)
      ORDER BY sl.updatedAt DESC, sl.id DESC
      LIMIT 500
    ''',
      [q, like, like, like, like],
    );

    return rows.map((m) {
      return StockLevelRow(
        id: (m['id'] as int).toString(),
        productLabel: (m['productLabel'] as String?) ?? '',
        companyLabel: (m['companyLabel'] as String?) ?? '',
        stockOnHand: (m['stockOnHand'] as int?) ?? 0,
        stockAllocated: (m['stockAllocated'] as int?) ?? 0,
        updatedAt:
            DateTime.tryParse((m['updatedAt'] as String?) ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<StockLevel?> findById(String id) async {
    final rows = await db.query(
      'stock_level',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final m = rows.first;
    return StockLevel(
      id: m['id'] as int?,
      productVariantId: (m['productVariantId'] as int),
      companyId: (m['companyId'] as String),
      stockOnHand: (m['stockOnHand'] as int),
      stockAllocated: (m['stockAllocated'] as int),
      createdAt:
          DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((m['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  @override
  Future<int> create(StockLevel level) async {
    final id = await db.insert('stock_level', {
      'productVariantId': level.productVariantId,
      'companyId': level.companyId,
      'stockOnHand': level.stockOnHand,
      'stockAllocated': level.stockAllocated,
      'createdAt': level.createdAt.toIso8601String(),
      'updatedAt': level.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.abort);
    return id;
  }

  @override
  Future<void> update(StockLevel level) async {
    await db.update(
      'stock_level',
      {
        'productVariantId': level.productVariantId,
        'companyId': level.companyId,
        'stockOnHand': level.stockOnHand,
        'stockAllocated': level.stockAllocated,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [level.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> delete(String id) async {
    await db.delete('stock_level', where: 'id = ?', whereArgs: [int.parse(id)]);
  }

  @override
  Future<List<Map<String, Object?>>> listProductVariants({
    String query = '',
  }) async {
    final q = query.trim();
    final like = '%$q%';
    return db.rawQuery(
      '''
      SELECT id, COALESCE(name, code, 'Variant #'||id) AS label
      FROM product
      WHERE (? = '' OR name LIKE ? OR code LIKE ?)
      ORDER BY (name IS NULL), name, (code IS NULL), code, id DESC
      LIMIT 200
    ''',
      [q, like, like],
    );
  }

  @override
  Future<List<Map<String, Object?>>> listCompanies({String query = ''}) async {
    final q = query.trim();
    final like = '%$q%';
    return db.rawQuery(
      '''
      SELECT id, COALESCE(name, code, id) AS label
      FROM company
      WHERE deletedAt IS NULL AND (? = '' OR name LIKE ? OR code LIKE ?)
      ORDER BY (name IS NULL), name, (code IS NULL), code, id DESC
      LIMIT 200
    ''',
      [q, like, like],
    );
  }
}
