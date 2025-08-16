// Use case that appends a sale to customer's open debt, records stock OUT, logs changes, and refreshes customer balances.
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/debts/entities/debt.dart';
import 'package:money_pulse/domain/debts/repositories/debt_repository.dart';

class AddSaleToDebtUseCase {
  final AppDatabase db;
  final DebtRepository debtRepo;
  AddSaleToDebtUseCase(this.db, this.debtRepo);

  Future<String> execute({
    required String customerId,
    String? companyId,
    String? categoryId,
    String? description,
    required DateTime when,
    required List<Map<String, Object?>> lines,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('lines cannot be empty');
    }

    int _i(Object? v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;

    int totalCents = 0;
    for (final e in lines) {
      final q = _i(e['quantity']);
      final u = _i(e['unitPrice']);
      final safeQ = q < 0 ? 0 : q;
      final safeU = u < 0 ? 0 : u;
      totalCents += safeQ * safeU;
    }

    final txId = const Uuid().v4();
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    await db.tx((txn) async {
      final resolvedCompany = await _resolveCompanyId(txn, companyId);
      final Debt open = await debtRepo.upsertOpenForCustomerTx(txn, customerId);

      await txn.insert('transaction_entry', {
        'id': txId,
        'remoteId': null,
        'code': null,
        'description': description,
        'amount': totalCents,
        'typeEntry': 'DEBT',
        'dateTransaction': when.toIso8601String(),
        'status': 'DEBT',
        'entityName': 'CUSTOMER',
        'entityId': customerId,
        'accountId': null,
        'categoryId': categoryId,
        'companyId': resolvedCompany,
        'customerId': customerId,
        'debtId': open.id,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'deletedAt': null,
        'syncAt': null,
        'version': 0,
        'isDirty': 1,
      });

      for (final e in lines) {
        final itemId = const Uuid().v4();
        final qty = _i(e['quantity']);
        final up = _i(e['unitPrice']);
        final safeQty = qty < 0 ? 0 : qty;
        final safeUp = up < 0 ? 0 : up;
        final tot = safeQty * safeUp;

        await txn.insert('transaction_item', {
          'id': itemId,
          'transactionId': txId,
          'productId': e['productId']?.toString(),
          'label': (e['label'] ?? '').toString(),
          'quantity': safeQty,
          'unitId': e['unitId']?.toString(),
          'unitPrice': safeUp,
          'total': tot,
          'notes': null,
          'createdAt': nowIso,
          'updatedAt': nowIso,
          'deletedAt': null,
          'syncAt': null,
          'version': 0,
          'isDirty': 1,
        });

        final pid = (e['productId']?.toString() ?? '');
        if (pid.isNotEmpty &&
            safeQty > 0 &&
            (resolvedCompany ?? '').isNotEmpty) {
          final movementId = await txn.insert('stock_movement', {
            'type_stock_movement': 'OUT',
            'quantity': safeQty,
            'companyId': resolvedCompany,
            'productVariantId': pid,
            'orderLineId': itemId,
            'discriminator': 'TXN',
            'createdAt': nowIso,
            'updatedAt': nowIso,
          });
          await _upsertChangeLog(
            txn,
            'stock_movement',
            '$movementId',
            'INSERT',
            nowIso,
          );
        }
      }

      await _applyStockAdjustments(
        txn: txn,
        lines: lines,
        companyId: companyId ?? resolvedCompany,
        nowIso: nowIso,
      );

      final newBalance = open.balance + totalCents;
      await debtRepo.updateBalanceTx(txn, open.id, newBalance);

      await _upsertChangeLog(txn, 'transaction_entry', txId, 'INSERT', nowIso);

      await _recomputeCustomerBalances(txn, customerId, nowIso);
    });

    return txId;
  }

  Future<void> _recomputeCustomerBalances(
    Transaction txn,
    String cid,
    String nowIso,
  ) async {
    await txn.rawUpdate(
      '''
      UPDATE customer
      SET balanceDebt = COALESCE((
            SELECT SUM(COALESCE(d.balance,0))
            FROM debt d
            WHERE d.customerId = ?
              AND d.deletedAt IS NULL
              AND (d.statuses IS NULL OR d.statuses='OPEN')
          ),0),
          balance = COALESCE((
            SELECT SUM(
              CASE te.typeEntry
                WHEN 'CREDIT' THEN COALESCE(te.amount,0)
                WHEN 'DEBIT' THEN -COALESCE(te.amount,0)
                WHEN 'REMBOURSEMENT' THEN -COALESCE(te.amount,0)
                WHEN 'PRET' THEN COALESCE(te.amount,0)
                WHEN 'DEBT' THEN COALESCE(te.amount,0)
                ELSE 0
              END
            )
            FROM transaction_entry te
            WHERE te.customerId = ?
              AND te.deletedAt IS NULL
          ),0),
          updatedAt = ?,
          isDirty = 1
      WHERE id = ?
      ''',
      [cid, cid, nowIso, cid],
    );
  }

  Future<void> _applyStockAdjustments({
    required Transaction txn,
    required List<Map<String, Object?>> lines,
    required String? companyId,
    required String nowIso,
  }) async {
    final company = (companyId ?? '').isEmpty ? null : companyId;
    if (company == null) return;

    final Map<String, int> totalsByVariant = {};
    for (final e in lines) {
      final pid = e['productId']?.toString();
      final qty = e['quantity'] is int
          ? e['quantity'] as int
          : int.tryParse('${e['quantity'] ?? 0}') ?? 0;
      if ((pid ?? '').isEmpty || qty <= 0) continue;
      totalsByVariant[pid!] = (totalsByVariant[pid] ?? 0) + qty;
    }
    if (totalsByVariant.isEmpty) return;

    for (final entry in totalsByVariant.entries) {
      final pvId = entry.key;
      final qty = -entry.value;

      final row = await txn.rawQuery(
        'SELECT id FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1',
        [pvId, company],
      );

      if (row.isEmpty) {
        await txn.insert('stock_level', {
          'productVariantId': pvId,
          'companyId': company,
          'stockOnHand': 0,
          'stockAllocated': 0,
          'createdAt': nowIso,
          'updatedAt': nowIso,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await _upsertChangeLog(
          txn,
          'stock_level',
          '$pvId@$company',
          'INSERT',
          nowIso,
        );
      }

      await txn.rawUpdate(
        'UPDATE stock_level SET stockOnHand = COALESCE(stockOnHand,0) + ?, updatedAt=? WHERE productVariantId=? AND companyId=?',
        [qty, nowIso, pvId, company],
      );
      await _upsertChangeLog(
        txn,
        'stock_level',
        '$pvId@$company',
        'UPDATE',
        nowIso,
      );
    }
  }

  Future<String?> _resolveCompanyId(Transaction txn, String? provided) async {
    if ((provided ?? '').isNotEmpty) return provided;
    final def = await txn.rawQuery(
      'SELECT id FROM company WHERE isDefault=1 AND deletedAt IS NULL LIMIT 1',
    );
    return def.isEmpty ? null : (def.first['id'] as String?);
  }

  Future<void> _upsertChangeLog(
    Transaction txn,
    String entityTable,
    String entityId,
    String operation,
    String nowIso,
  ) async {
    final idLog = const Uuid().v4();
    await txn.rawInsert(
      '''
      INSERT INTO change_log(
        id, entityTable, entityId, operation, payload, status, attempts, error, createdAt, updatedAt, processedAt
      )
      VALUES(?,?,?,?,?,?,?,?,?,?,?)
      ON CONFLICT(entityTable, entityId, status) DO UPDATE SET
        operation=excluded.operation,
        updatedAt=excluded.updatedAt,
        payload=excluded.payload
      ''',
      [
        idLog,
        entityTable,
        entityId,
        operation,
        null,
        'PENDING',
        0,
        null,
        nowIso,
        nowIso,
        null,
      ],
    );
  }
}
