// lib/infrastructure/stock/stock_level_repository_sqflite.dart
//
// StockLevel repository refactored to use ChangeTrackedExec helpers:
// - insertTracked / updateTracked for auto UTC timestamps, isDirty, version++, and change_log upsert
// - Idempotent ensure row
// - Reusable movement insert
// - No negative stock (clamped to 0)
// - UpdatedAt ordering kept for search
//
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../infrastructure/db/app_database.dart';
import '../../../domain/stock/entities/stock_level.dart';
import '../../../domain/stock/repositories/stock_level_repository.dart';
import '../../../sync/infrastructure/change_log_helper.dart';
import '../../../sync/infrastructure/change_tracked_exec.dart'; // 👈 extensions

class StockLevelRepositorySqflite implements StockLevelRepository {
  final AppDatabase app;
  late final Database db;

  StockLevelRepositorySqflite(this.app) : db = app.db;

  String _nowUtcIso() => DateTime.now().toUtc().toIso8601String();

  /// Ensure a stock_level row exists for (productVariantId, companyId) and return its `id`.
  Future<String> _ensureLevelRow(
    Transaction txn, {
    required String productVariantId,
    required String companyId,
    required String nowIso,
  }) async {
    final existing = await txn.rawQuery(
      'SELECT id FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1',
      [productVariantId, companyId],
    );
    if (existing.isNotEmpty) {
      return (existing.first['id'] as String);
    }
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
    return id;
  }

  /// Insert a stock movement and log it; returns movement id.
  Future<String> _insertMovement(
    Transaction txn, {
    required String type, // ADJUST | ALLOCATE | RELEASE
    required int quantity, // always positive
    required String companyId,
    required String productVariantId,
    String? orderLineId,
    String discriminator = 'FORM',
    String? reason, // optional override of discriminator/notes
    String? nowIso,
  }) async {
    final idMvts = const Uuid().v4();
    final when = nowIso ?? _nowUtcIso();

    await txn.insertTracked('stock_movement', {
      'id': idMvts,
      'type_stock_movement': type,
      'quantity': quantity.abs(),
      'companyId': companyId,
      'productVariantId': productVariantId,
      'orderLineId': orderLineId,
      'discriminator': (reason != null && reason.trim().isNotEmpty)
          ? reason.trim()
          : discriminator,
      'createdAt': when,
      'updatedAt': when,
      'syncAt': null,
      'version': 0,
      'remoteId': null,
      'localId': null,
    }, operation: 'INSERT');

    return idMvts;
  }

  @override
  Future<List<StockLevelRow>> search({String query = ''}) async {
    final q = query.trim().toLowerCase();
    final like = '%$q%';
    final rows = await db.rawQuery(
      '''
      SELECT sl.id,
             sl.stockOnHand,
             sl.stockAllocated,
             sl.updatedAt,
             COALESCE(p.name, p.code, 'Produit') AS productLabel,
             COALESCE(c.name, c.code, sl.companyId) AS companyLabel
      FROM stock_level sl
      LEFT JOIN product p ON p.id = sl.productVariantId
      LEFT JOIN company c ON c.id = sl.companyId
      WHERE (? = '' 
         OR lower(COALESCE(p.name,'')) LIKE ?
         OR lower(COALESCE(p.code,'')) LIKE ?
         OR lower(COALESCE(c.name,'')) LIKE ?
         OR lower(COALESCE(c.code,'')) LIKE ?)
      ORDER BY datetime(sl.updatedAt) DESC, sl.id DESC
      LIMIT 500
      ''',
      [q, like, like, like, like],
    );

    return rows.map((m) {
      return StockLevelRow(
        id: (m['id'] ?? "N/A").toString(),
        productLabel: (m['productLabel'] as String?) ?? '',
        companyLabel: (m['companyLabel'] as String?) ?? '',
        stockOnHand: (m['stockOnHand'] as int?) ?? 0,
        stockAllocated: (m['stockAllocated'] as int?) ?? 0,
        updatedAt:
            DateTime.tryParse((m['updatedAt'] as String?) ?? '')?.toUtc() ??
            DateTime.now().toUtc(),
      );
    }).toList();
  }

  @override
  Future<StockLevel?> findById(String id) async {
    final rows = await db.query(
      'stock_level',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final m = rows.first;
    return StockLevel(
      id: id,
      productVariantId: (m['productVariantId'] as String),
      companyId: (m['companyId'] as String),
      stockOnHand: (m['stockOnHand'] as int?) ?? 0,
      stockAllocated: (m['stockAllocated'] as int?) ?? 0,
      createdAt:
          DateTime.tryParse((m['createdAt'] as String?) ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse((m['updatedAt'] as String?) ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  @override
  Future<String> create(StockLevel level) async {
    final now = _nowUtcIso();
    final idStock = const Uuid().v4();

    return await db.transaction<String>((txn) async {
      await txn.insertTracked('stock_level', {
        'id': idStock,
        'productVariantId': level.productVariantId,
        'companyId': level.companyId,
        'stockOnHand': level.stockOnHand,
        'stockAllocated': level.stockAllocated,
        'createdAt': now,
        'updatedAt': now,
        'version': 0,
      }, operation: 'INSERT');

      // Initial movements if non-zero
      if (level.stockOnHand != 0) {
        await _insertMovement(
          txn,
          type: 'ADJUST',
          quantity: level.stockOnHand.abs(),
          companyId: level.companyId,
          productVariantId: level.productVariantId,
          discriminator: 'INIT',
          nowIso: now,
        );
      }
      if (level.stockAllocated != 0) {
        await _insertMovement(
          txn,
          type: level.stockAllocated > 0 ? 'ALLOCATE' : 'RELEASE',
          quantity: level.stockAllocated.abs(),
          companyId: level.companyId,
          productVariantId: level.productVariantId,
          discriminator: 'INIT',
          nowIso: now,
        );
      }

      return idStock;
    });
  }

  @override
  Future<void> update(StockLevel level) async {
    final now = _nowUtcIso();
    await db.transaction((txn) async {
      final prevRows = await txn.query(
        'stock_level',
        columns: [
          'productVariantId',
          'companyId',
          'stockOnHand',
          'stockAllocated',
        ],
        where: 'id = ?',
        whereArgs: [level.id],
        limit: 1,
      );

      int prevOn = 0;
      int prevAl = 0;

      if (prevRows.isNotEmpty) {
        final m = prevRows.first;
        prevOn = (m['stockOnHand'] as int?) ?? 0;
        prevAl = (m['stockAllocated'] as int?) ?? 0;
      }

      // Clamp negatives to zero
      final nextOn = level.stockOnHand < 0 ? 0 : level.stockOnHand;

      // Persist (auto updatedAt/isDirty/version++ + change_log)
      await txn.updateTracked(
        'stock_level',
        {
          'productVariantId': level.productVariantId,
          'companyId': level.companyId,
          'stockOnHand': nextOn,
          'stockAllocated': level.stockAllocated,
          // updatedAt/isDirty handled by updateTracked
        },
        where: 'id = ?',
        whereArgs: [level.id],
        entityId: level.id,
        operation: 'UPDATE',
      );

      // Movements for deltas (on the *new* product/company)
      final dOn = nextOn - prevOn;
      if (dOn != 0) {
        await _insertMovement(
          txn,
          type: 'ADJUST',
          quantity: dOn.abs(),
          companyId: level.companyId,
          productVariantId: level.productVariantId,
          discriminator: dOn > 0 ? 'FORM_INC' : 'FORM_DEC',
          nowIso: now,
        );
      }

      final dAl = level.stockAllocated - prevAl;
      if (dAl != 0) {
        await _insertMovement(
          txn,
          type: dAl > 0 ? 'ALLOCATE' : 'RELEASE',
          quantity: dAl.abs(),
          companyId: level.companyId,
          productVariantId: level.productVariantId,
          discriminator: 'FORM',
          nowIso: now,
        );
      }
    });
  }

  @override
  Future<void> delete(String id) async {
    // Hard delete (stock_level has no deletedAt in your schema)
    await db.transaction((txn) async {
      await txn.delete('stock_level', where: 'id = ?', whereArgs: [id]);
      // Manually log since softDeleteTracked can't be used (no deletedAt column)
      await upsertChangeLogPending(
        txn,
        entityTable: 'stock_level',
        entityId: id,
        operation: 'DELETE',
      );
    });
  }

  Future<void> _applyOnHandDelta(
    Transaction txn, {
    required String productVariantId,
    required String companyId,
    required int delta, // can be +/-; 0 ignored
    String? orderLineId,
    String? reason,
    required String now,
  }) async {
    if (delta == 0) return;

    final idStock = await _ensureLevelRow(
      txn,
      productVariantId: productVariantId,
      companyId: companyId,
      nowIso: now,
    );

    // Read current
    final curRow = await txn.rawQuery(
      'SELECT stockOnHand FROM stock_level WHERE id=? LIMIT 1',
      [idStock],
    );
    final cur = curRow.isEmpty
        ? 0
        : ((curRow.first['stockOnHand'] as int?) ?? 0);

    final next = cur + delta;
    final newVal = next < 0 ? 0 : next;

    // Persist with tracked update (auto updatedAt/isDirty/version++ + change_log)
    await txn.updateTracked(
      'stock_level',
      {'stockOnHand': newVal},
      where: 'id = ?',
      whereArgs: [idStock],
      entityId: idStock,
      operation: 'UPDATE',
    );

    // Movement
    await _insertMovement(
      txn,
      type: 'ADJUST',
      quantity: delta.abs(),
      companyId: companyId,
      productVariantId: productVariantId,
      orderLineId: orderLineId,
      discriminator: delta > 0 ? 'INC' : 'DEC',
      reason: reason,
      nowIso: now,
    );
  }

  @override
  Future<void> adjustOnHandBy({
    required String productVariantId,
    required String companyId,
    required int delta,
    String? orderLineId,
    String? reason,
  }) async {
    if (delta == 0) return;
    final now = _nowUtcIso();
    await db.transaction((txn) async {
      await _applyOnHandDelta(
        txn,
        productVariantId: productVariantId,
        companyId: companyId,
        delta: delta,
        orderLineId: orderLineId,
        reason: reason,
        now: now,
      );
    });
  }

  @override
  Future<void> adjustOnHandTo({
    required String productVariantId,
    required String companyId,
    required int target,
    String? orderLineId,
    String? reason,
  }) async {
    final now = _nowUtcIso();
    await db.transaction((txn) async {
      final idStock = await _ensureLevelRow(
        txn,
        productVariantId: productVariantId,
        companyId: companyId,
        nowIso: now,
      );

      final curRow = await txn.rawQuery(
        'SELECT stockOnHand FROM stock_level WHERE id=? LIMIT 1',
        [idStock],
      );
      final cur = curRow.isEmpty
          ? 0
          : ((curRow.first['stockOnHand'] as int?) ?? 0);

      final safeTarget = target < 0 ? 0 : target;
      final delta = safeTarget - cur;
      if (delta == 0) return;

      await _applyOnHandDelta(
        txn,
        productVariantId: productVariantId,
        companyId: companyId,
        delta: delta,
        orderLineId: orderLineId,
        reason: reason,
        now: now,
      );
    });
  }

  @override
  Future<List<Map<String, Object?>>> listProductVariants({String query = ''}) {
    final q = query.trim().toLowerCase();
    final like = '%$q%';
    return db.rawQuery(
      '''
      SELECT id, COALESCE(name, code, 'Produit') AS label
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
  Future<List<Map<String, Object?>>> listCompanies({String query = ''}) {
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
}
