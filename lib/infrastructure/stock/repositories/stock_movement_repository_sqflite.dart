// lib/infrastructure/stock/stock_movement_repository_sqflite.dart
//
// StockMovement repository refactored to use ChangeTrackedExec helpers:
// - insertTracked / updateTracked for auto UTC timestamps, isDirty, version++, and change_log upsert
// - Atomic stock_level impact with tracked updates (no double counting)
// - Idempotent ensure stock_level row
// - Hard delete for movements (table has no deletedAt), with manual change_log upsert
//
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../infrastructure/db/app_database.dart';
import '../../../domain/stock/entities/stock_movement.dart';
import '../../../domain/stock/repositories/stock_movement_repository.dart';
import '../../../sync/infrastructure/change_log_helper.dart';
import '../../../sync/infrastructure/change_tracked_exec.dart';

class StockMovementRepositorySqflite implements StockMovementRepository {
  final AppDatabase app;
  late final Database db;

  StockMovementRepositorySqflite(this.app) : db = app.db;

  String _nowUtcIso() => DateTime.now().toUtc().toIso8601String();

  /// Ensure a stock_level row exists for (productVariantId, companyId) and return its map (id, onHand, allocated).
  Future<Map<String, Object?>> _ensureLevelRow(
    Transaction txn, {
    required String productVariantId,
    required String companyId,
    required String nowIso,
  }) async {
    final rows = await txn.rawQuery(
      'SELECT id, stockOnHand, stockAllocated FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1',
      [productVariantId, companyId],
    );
    if (rows.isNotEmpty) return rows.first;

    final id = const Uuid().v4();
    await txn.insertTracked('stock_level', {
      'id': id,
      'productVariantId': productVariantId,
      'companyId': companyId,
      'stockOnHand': 0,
      'stockAllocated': 0,
      'createdAt': nowIso,
      'updatedAt': nowIso,
      'version': 0,
    }, operation: 'INSERT');

    return {'id': id, 'stockOnHand': 0, 'stockAllocated': 0};
  }

  /// Apply the logical impact of a movement to stock_level using tracked update.
  Future<void> _applyImpact(
    Transaction txn, {
    required String type,
    required int qty,
    required String productVariantId,
    required String companyId,
    required String nowIso,
    required int multiplier, // +1 apply, -1 revert
  }) async {
    final base = await _ensureLevelRow(
      txn,
      productVariantId: productVariantId,
      companyId: companyId,
      nowIso: nowIso,
    );

    int onHand = (base['stockOnHand'] as int?) ?? 0;
    int allocated = (base['stockAllocated'] as int?) ?? 0;

    int deltaOn = 0;
    int deltaAl = 0;

    switch (type) {
      case 'IN':
        deltaOn = qty * multiplier;
        break;
      case 'OUT':
        deltaOn = -qty * multiplier;
        break;
      case 'ALLOCATE':
        deltaAl = qty * multiplier;
        break;
      case 'RELEASE':
        deltaAl = -qty * multiplier;
        break;
      case 'ADJUST':
        deltaOn = qty * multiplier;
        break;
      default:
        break;
    }

    final newOn = (onHand + deltaOn) < 0 ? 0 : (onHand + deltaOn);
    final newAl = (allocated + deltaAl) < 0 ? 0 : (allocated + deltaAl);

    // Update the row with tracked helper (auto updatedAt/isDirty/version++ + change_log)
    final idRow = await txn.rawQuery(
      'SELECT id FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1',
      [productVariantId, companyId],
    );
    final idStock =
        (idRow.isNotEmpty ? (idRow.first['id'] as String?) : null) ?? '';
    if (idStock.isEmpty) return;

    await txn.updateTracked(
      'stock_level',
      {'stockOnHand': newOn, 'stockAllocated': newAl},
      where: 'id = ?',
      whereArgs: [idStock],
      entityId: idStock,
      operation: 'UPDATE',
    );
  }

  /// Insert a stock movement row using tracked helper; returns inserted id.
  Future<String> _insertMovement(
    Transaction txn, {
    required String type, // IN | OUT | ADJUST | ALLOCATE | RELEASE
    required int quantity,
    required String companyId,
    required String productVariantId,
    String? orderLineId,
    String? discriminator,
    DateTime? createdAt,
  }) async {
    final id = const Uuid().v4();
    await txn.insertTracked('stock_movement', {
      'id': id,
      'type_stock_movement': type,
      'quantity': quantity.abs(),
      'companyId': companyId,
      'productVariantId': productVariantId,
      'orderLineId': orderLineId,
      'discriminator': discriminator,
      'createdAt': (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
      // updatedAt/isDirty/version handled by insertTracked
      'syncAt': null,
      'remoteId': null,
      'localId': null,
    }, operation: 'INSERT');
    return id;
  }

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
      whereArgs: [id],
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
      [id],
    );
    if (rows.isEmpty) return null;
    return _toRow(rows.first);
  }

  @override
  Future<int> create(StockMovement m) async {
    final now = _nowUtcIso();

    return await db.transaction<int>((txn) async {
      // 1) Insert movement (tracked)
      final inserted = await txn.insertTracked('stock_movement', {
        'id': (m.id is String && (m.id as String).isNotEmpty)
            ? m.id
            : const Uuid().v4(),
        'type_stock_movement': m.type,
        'quantity': m.quantity,
        'companyId': m.companyId,
        'productVariantId': m.productVariantId,
        'orderLineId': m.orderLineId,
        'discriminator': m.discriminator,
        'createdAt': m.createdAt.toUtc().toIso8601String(),
        // updatedAt/isDirty/version handled by helper
        'syncAt': null,
        'remoteId': null,
        'localId': null,
      }, operation: 'INSERT');

      // 2) Apply impact (tracked update on stock_level)
      await _applyImpact(
        txn,
        type: m.type,
        qty: m.quantity,
        productVariantId: m.productVariantId,
        companyId: m.companyId,
        nowIso: now,
        multiplier: 1,
      );

      return inserted;
    });
  }

  @override
  Future<void> update(StockMovement m) async {
    final now = _nowUtcIso();
    await db.transaction((txn) async {
      // Load previous
      final prevRows = await txn.query(
        'stock_movement',
        where: 'id = ?',
        whereArgs: [m.id],
        limit: 1,
      );
      if (prevRows.isEmpty) return;
      final prev = StockMovement.fromMap(prevRows.first);

      // 1) Revert previous impact
      await _applyImpact(
        txn,
        type: prev.type,
        qty: prev.quantity,
        productVariantId: prev.productVariantId,
        companyId: prev.companyId,
        nowIso: now,
        multiplier: -1,
      );

      // 2) Update movement (tracked)
      await txn.updateTracked(
        'stock_movement',
        {
          'type_stock_movement': m.type,
          'quantity': m.quantity,
          'companyId': m.companyId,
          'productVariantId': m.productVariantId,
          'orderLineId': m.orderLineId,
          'discriminator': m.discriminator,
          // updatedAt/isDirty/version handled by helper
        },
        where: 'id = ?',
        whereArgs: [m.id],
        entityId: m.id as String,
        operation: 'UPDATE',
      );

      // 3) Apply new impact
      await _applyImpact(
        txn,
        type: m.type,
        qty: m.quantity,
        productVariantId: m.productVariantId,
        companyId: m.companyId,
        nowIso: now,
        multiplier: 1,
      );
    });
  }

  @override
  Future<void> delete(String id) async {
    final now = _nowUtcIso();
    await db.transaction((txn) async {
      // Load previous
      final prevRows = await txn.query(
        'stock_movement',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (prevRows.isEmpty) return;
      final prev = StockMovement.fromMap(prevRows.first);

      // 1) Hard delete (no deletedAt column on stock_movement)
      await txn.delete('stock_movement', where: 'id = ?', whereArgs: [id]);

      // 2) Revert impact
      await _applyImpact(
        txn,
        type: prev.type,
        qty: prev.quantity,
        productVariantId: prev.productVariantId,
        companyId: prev.companyId,
        nowIso: now,
        multiplier: -1,
      );

      // 3) Manually log DELETE (since softDeleteTracked isn't applicable)
      await upsertChangeLogPending(
        txn,
        entityTable: 'stock_movement',
        entityId: id,
        operation: 'DELETE',
      );
    });
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
      id: (m['id'] ?? "N/A") as String,
      productLabel: (m['productLabel'] as String?) ?? '',
      companyLabel: (m['companyLabel'] as String?) ?? '',
      type: (m['type'] as String?) ?? '',
      quantity: (m['quantity'] as int?) ?? 0,
      unitPriceCents: (m['unitPriceCents'] as int?) ?? 0,
      totalCents: (m['totalCents'] as int?) ?? 0,
      createdAt:
          DateTime.tryParse((m['createdAt'] as String?) ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      orderLineId: m['orderLineId'] as String?,
    );
  }
}
