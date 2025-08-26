/// Sqflite repository for StockLevel with TEXT productVariantId, label lookups,
/// change_log entries and automatic stock_movement insertions on update/create.
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../infrastructure/db/app_database.dart';
import '../../../domain/stock/entities/stock_level.dart';
import '../../../domain/stock/repositories/stock_level_repository.dart';

class StockLevelRepositorySqflite implements StockLevelRepository {
  final AppDatabase app;
  late final Database db;

  StockLevelRepositorySqflite(this.app) : db = app.db;

  String _nowIso() => DateTime.now().toIso8601String();

  Future<void> _upsertChangeLog(
    Transaction txn, {
    required String table,
    required String entityId,
    required String op,
    String? payload,
  }) async {
    final idLog = const Uuid().v4();
    final now = _nowIso();
    await txn.rawInsert(
      '''
      INSERT INTO change_log(
        id, entityTable, entityId, operation, payload, status, attempts, error, createdAt, updatedAt, processedAt
      )
      VALUES(?,?,?,?,?,'PENDING',0,NULL,?, ?, NULL)
      ON CONFLICT(entityTable, entityId, status) DO UPDATE SET
        operation=excluded.operation,
        payload=excluded.payload,
        updatedAt=excluded.updatedAt
      ''',
      [idLog, table, entityId, op, payload, now, now],
    );
  }

  Future<void> _ensureLevelRow(
    Transaction txn, {
    required String productVariantId,
    required String companyId,
    required String nowIso,
  }) async {
    final exists = await txn.rawQuery(
      'SELECT id FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1',
      [productVariantId, companyId],
    );
    if (exists.isEmpty) {
      final id = const Uuid().v4();
      await txn.insert('stock_level', {
        'productVariantId': productVariantId,
        'companyId': companyId,
        'stockOnHand': 0,
        'stockAllocated': 0,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'id': id,
      });
      await _upsertChangeLog(
        txn,
        table: 'stock_level',
        entityId: id,
        op: 'INSERT',
      );
    }
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
        id: (m['id'] as String).toString(),
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
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final m = rows.first;
    return StockLevel(
      id: id,
      productVariantId: (m['productVariantId'] as String),
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
  Future<String> create(StockLevel level) async {
    final now = _nowIso();
    final idStock = const Uuid().v4();
    final idMvts = const Uuid().v4();

    return await db.transaction<String>((txn) async {
      final id = await txn.insert('stock_level', {
        'productVariantId': level.productVariantId,
        'companyId': level.companyId,
        'stockOnHand': level.stockOnHand,
        'stockAllocated': level.stockAllocated,
        'createdAt': now,
        'updatedAt': now,
        'id': idStock,
      }, conflictAlgorithm: ConflictAlgorithm.abort);

      if (level.stockOnHand != 0) {
        await txn.insert('stock_movement', {
          'type_stock_movement': 'ADJUST',
          'quantity': level.stockOnHand.abs(),
          'companyId': level.companyId,
          'productVariantId': level.productVariantId,
          'orderLineId': null,
          'discriminator': 'INIT',
          'createdAt': now,
          'updatedAt': now,
          'id': idMvts,
        });
        await _upsertChangeLog(
          txn,
          table: 'stock_movement',
          entityId: idMvts,
          op: 'INSERT',
        );
      }
      if (level.stockAllocated != 0) {
        final t = level.stockAllocated > 0 ? 'ALLOCATE' : 'RELEASE';
        await txn.insert('stock_movement', {
          'type_stock_movement': t,
          'quantity': level.stockAllocated.abs(),
          'companyId': level.companyId,
          'productVariantId': level.productVariantId,
          'orderLineId': null,
          'discriminator': 'INIT',
          'createdAt': now,
          'updatedAt': now,
          'id': idMvts,
        });
        await _upsertChangeLog(
          txn,
          table: 'stock_movement',
          entityId: idMvts,
          op: 'INSERT',
        );
      }

      await _upsertChangeLog(
        txn,
        table: 'stock_level',
        entityId: idStock,
        op: 'INSERT',
      );
      return idStock;
    });
  }

  @override
  Future<void> update(StockLevel level) async {
    final idStock = level.id;

    final now = _nowIso();
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
      String prevPv = level.productVariantId;
      String prevCo = level.companyId;
      int prevOn = 0;
      int prevAl = 0;
      if (prevRows.isNotEmpty) {
        final m = prevRows.first;
        prevPv = (m['productVariantId'] as String?) ?? prevPv;
        prevCo = (m['companyId'] as String?) ?? prevCo;
        prevOn = (m['stockOnHand'] as int?) ?? 0;
        prevAl = (m['stockAllocated'] as int?) ?? 0;
      }

      await txn.update(
        'stock_level',
        {
          'productVariantId': level.productVariantId,
          'companyId': level.companyId,
          'stockOnHand': level.stockOnHand,
          'stockAllocated': level.stockAllocated,
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [level.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final dOn = level.stockOnHand - prevOn;
      if (dOn != 0) {
        final idMvts = const Uuid().v4();

        await txn.insert('stock_movement', {
          'type_stock_movement': 'ADJUST',
          'quantity': dOn.abs(),
          'companyId': level.companyId,
          'productVariantId': level.productVariantId,
          'orderLineId': null,
          'discriminator': dOn > 0 ? 'FORM_INC' : 'FORM_DEC',
          'createdAt': now,
          'updatedAt': now,
          'id': idMvts,
        });
        await _upsertChangeLog(
          txn,
          table: 'stock_movement',
          entityId: idMvts,
          op: 'INSERT',
        );
      }

      final dAl = level.stockAllocated - prevAl;
      if (dAl != 0) {
        final idMvts = const Uuid().v4();
        final t = dAl > 0 ? 'ALLOCATE' : 'RELEASE';
        await txn.insert('stock_movement', {
          'type_stock_movement': t,
          'quantity': dAl.abs(),
          'companyId': level.companyId,
          'productVariantId': level.productVariantId,
          'orderLineId': null,
          'discriminator': 'FORM',
          'createdAt': now,
          'updatedAt': now,
          'id': idMvts,
        });
        await _upsertChangeLog(
          txn,
          table: 'stock_movement',
          entityId: idMvts,
          op: 'INSERT',
        );
      }

      await _upsertChangeLog(
        txn,
        table: 'stock_level',
        entityId: '${level.id}',
        op: 'UPDATE',
      );
    });
  }

  @override
  Future<void> delete(String id) async {
    await db.transaction((txn) async {
      await txn.delete('stock_level', where: 'id = ?', whereArgs: [id]);
      await _upsertChangeLog(
        txn,
        table: 'stock_level',
        entityId: id,
        op: 'DELETE',
      );
    });
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
    final now = _nowIso();
    final disc = (reason != null && reason.trim().isNotEmpty)
        ? reason.trim()
        : (delta > 0 ? 'INC' : 'DEC');

    await db.transaction((txn) async {
      await _ensureLevelRow(
        txn,
        productVariantId: productVariantId,
        companyId: companyId,
        nowIso: now,
      );

      final curRow = await txn.rawQuery(
        'SELECT stockOnHand, id FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1',
        [productVariantId, companyId],
      );
      final cur = (curRow.isEmpty
          ? 0
          : (curRow.first['stockOnHand'] as int? ?? 0));
      final next = cur + delta;
      final newVal = next < 0 ? 0 : next;

      String idStock = curRow.first['id'] as String;

      await txn.rawUpdate(
        'UPDATE stock_level SET stockOnHand=?, updatedAt=? WHERE id=?',
        [newVal, now, idStock],
      );

      final idMvts = const Uuid().v4();

      await txn.insert('stock_movement', {
        'type_stock_movement': 'ADJUST',
        'quantity': delta.abs(),
        'companyId': companyId,
        'productVariantId': productVariantId,
        'orderLineId': orderLineId,
        'discriminator': disc,
        'createdAt': now,
        'updatedAt': now,
        'id': idMvts,
      });

      await _upsertChangeLog(
        txn,
        table: 'stock_level',
        entityId: idStock,
        op: 'UPDATE',
      );

      await _upsertChangeLog(
        txn,
        table: 'stock_movement',
        entityId: idMvts,
        op: 'INSERT',
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
    final now = _nowIso();
    await db.transaction((txn) async {
      await _ensureLevelRow(
        txn,
        productVariantId: productVariantId,
        companyId: companyId,
        nowIso: now,
      );

      final curRow = await txn.rawQuery(
        'SELECT stockOnHand , id FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1',
        [productVariantId, companyId],
      );
      final cur = (curRow.isEmpty
          ? 0
          : (curRow.first['stockOnHand'] as int? ?? 0));
      final safeTarget = target < 0 ? 0 : target;
      final delta = safeTarget - cur;
      if (delta == 0) return;

      final idStock = curRow.first['id'] as String;

      await txn.rawUpdate(
        'UPDATE stock_level SET stockOnHand=?, updatedAt=? WHERE productVariantId=? AND companyId=?',
        [safeTarget, now, productVariantId, companyId],
      );

      final disc = (reason != null && reason.trim().isNotEmpty)
          ? reason.trim()
          : (delta > 0 ? 'INC' : 'DEC');

      final idMvts = const Uuid().v4();

      await txn.insert('stock_movement', {
        'type_stock_movement': 'ADJUST',
        'quantity': delta.abs(),
        'companyId': companyId,
        'productVariantId': productVariantId,
        'orderLineId': orderLineId,
        'discriminator': disc,
        'createdAt': now,
        'updatedAt': now,
        'id': idMvts,
      });

      await _upsertChangeLog(
        txn,
        table: 'stock_level',
        entityId: idStock,
        op: 'UPDATE',
      );
      await _upsertChangeLog(
        txn,
        table: 'stock_movement',
        entityId: idMvts,
        op: 'INSERT',
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
}
