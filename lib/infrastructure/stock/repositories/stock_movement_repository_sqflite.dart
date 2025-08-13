/// Sqflite repository for StockMovement CRUD and search, exposing unit price and total.
import 'package:sqflite/sqflite.dart';
import '../../../infrastructure/db/app_database.dart';
import '../../../domain/stock/entities/stock_movement.dart';
import '../../../domain/stock/repositories/stock_movement_repository.dart';

class StockMovementRepositorySqflite implements StockMovementRepository {
  final AppDatabase app;
  late final Database db;
  StockMovementRepositorySqflite(this.app) : db = app.db;

  @override
  Future<List<StockMovementRow>> search({String query = ''}) async {
    final q = query.trim().toLowerCase();
    final like = '%$q%';
    final rows = await db.rawQuery(
      '''
      SELECT sm.id,
             sm.type_stock_movement AS type,
             sm.quantity,
             sm.orderLineId,
             sm.createdAt,
             COALESCE(p.name, p.code, sm.productVariantId)              AS productLabel,
             COALESCE(c.name, c.code, sm.companyId)                     AS companyLabel,
             COALESCE(ti.unitPrice, p.defaultPrice, 0)                  AS unitPriceCents,
             sm.quantity * COALESCE(ti.unitPrice, p.defaultPrice, 0)    AS totalCents
      FROM stock_movement sm
      LEFT JOIN product p           ON p.id = sm.productVariantId
      LEFT JOIN company c           ON c.id = sm.companyId
      LEFT JOIN transaction_item ti ON ti.id = sm.orderLineId
      WHERE (? = '' 
        OR lower(COALESCE(p.name,'')) LIKE ?
        OR lower(COALESCE(p.code,'')) LIKE ?
        OR lower(COALESCE(c.name,'')) LIKE ?
        OR lower(COALESCE(c.code,'')) LIKE ?
        OR lower(COALESCE(sm.type_stock_movement,'')) LIKE ?)
      ORDER BY datetime(sm.createdAt) DESC, sm.id DESC
      LIMIT 500
      ''',
      [q, like, like, like, like, like],
    );
    return rows.map(_toRow).toList();
  }

  @override
  Future<StockMovement?> findById(String id) async {
    final rows = await db.query(
      'stock_movement',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StockMovement.fromMap(rows.first);
  }

  @override
  Future<StockMovementRow?> findRowById(String id) async {
    final rows = await db.rawQuery(
      '''
      SELECT sm.id,
             sm.type_stock_movement AS type,
             sm.quantity,
             sm.orderLineId,
             sm.createdAt,
             COALESCE(p.name, p.code, sm.productVariantId)              AS productLabel,
             COALESCE(c.name, c.code, sm.companyId)                     AS companyLabel,
             COALESCE(ti.unitPrice, p.defaultPrice, 0)                  AS unitPriceCents,
             sm.quantity * COALESCE(ti.unitPrice, p.defaultPrice, 0)    AS totalCents
      FROM stock_movement sm
      LEFT JOIN product p           ON p.id = sm.productVariantId
      LEFT JOIN company c           ON c.id = sm.companyId
      LEFT JOIN transaction_item ti ON ti.id = sm.orderLineId
      WHERE sm.id = ?
      LIMIT 1
      ''',
      [int.parse(id)],
    );
    if (rows.isEmpty) return null;
    return _toRow(rows.first);
  }

  @override
  Future<int> create(StockMovement m) async {
    return await db.insert(
      'stock_movement',
      m.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> update(StockMovement m) async {
    await db.update(
      'stock_movement',
      m.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [m.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> delete(String id) async {
    await db.delete(
      'stock_movement',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }

  @override
  Future<List<Map<String, Object?>>> listProductVariants({
    String query = '',
  }) async {
    final q = query.trim().toLowerCase();
    final like = '%$q%';
    return db.rawQuery(
      '''
      SELECT id, COALESCE(name, code, 'Produit') AS label, COALESCE(defaultPrice,0) AS defaultPrice
      FROM product
      WHERE deletedAt IS NULL
        AND (? = '' OR lower(COALESCE(name,'')) LIKE ? OR lower(COALESCE(code,'')) LIKE ?)
      ORDER BY (name IS NULL), name COLLATE NOCASE, (code IS NULL), code COLLATE NOCASE, id DESC
      LIMIT 200
      ''',
      [q, like, like],
    );
  }

  @override
  Future<List<Map<String, Object?>>> listCompanies({String query = ''}) async {
    final q = query.trim().toLowerCase();
    final like = '%$q%';
    return db.rawQuery(
      '''
      SELECT id, COALESCE(name, code, id) AS label
      FROM company
      WHERE deletedAt IS NULL
        AND (? = '' OR lower(COALESCE(name,'')) LIKE ? OR lower(COALESCE(code,'')) LIKE ?)
      ORDER BY (name IS NULL), name COLLATE NOCASE, (code IS NULL), code COLLATE NOCASE, id DESC
      LIMIT 200
      ''',
      [q, like, like],
    );
  }

  StockMovementRow _toRow(Map<String, Object?> m) {
    return StockMovementRow(
      id: (m['id'] as int).toString(),
      productLabel: (m['productLabel'] as String?) ?? '',
      companyLabel: (m['companyLabel'] as String?) ?? '',
      type: (m['type'] as String?) ?? '',
      quantity: (m['quantity'] as int?) ?? 0,
      unitPriceCents: (m['unitPriceCents'] as int?) ?? 0,
      totalCents: (m['totalCents'] as int?) ?? 0,
      createdAt:
          DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      orderLineId: m['orderLineId'] as String?,
    );
  }
}
