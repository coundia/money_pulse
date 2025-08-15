// Use case to append a sale to a customer's open debt with stock OUT and no account change.
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
    final txId = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();

    int total(List<Map<String, Object?>> ls) {
      var sum = 0;
      for (final e in ls) {
        final q = (e['quantity'] as int?) ?? 1;
        final u = (e['unitPrice'] as int?) ?? 0;
        sum += q * u;
      }
      return sum;
    }

    final totalCents = total(lines);

    await db.tx((txn) async {
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
        'companyId': companyId,
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
        final qty = (e['quantity'] as int?) ?? 1;
        final unit = (e['unitPrice'] as int?) ?? 0;
        final total = qty * unit;
        await txn.insert('transaction_item', {
          'id': itemId,
          'transactionId': txId,
          'productId': e['productId'] as String?,
          'label': e['label'] as String?,
          'quantity': qty,
          'unitId': e['unitId'] as String?,
          'unitPrice': unit,
          'total': total,
          'notes': null,
          'createdAt': nowIso,
          'updatedAt': nowIso,
          'deletedAt': null,
          'syncAt': null,
          'version': 0,
          'isDirty': 1,
        });

        final pid = e['productId']?.toString() ?? '';
        if (pid.isNotEmpty && qty > 0 && (companyId ?? '').isNotEmpty) {
          final movementId = await txn.insert('stock_movement', {
            'type_stock_movement': 'OUT',
            'quantity': qty,
            'companyId': companyId,
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
        companyId: companyId,
        nowIso: nowIso,
      );

      final newBalance = open.balance + totalCents;
      await debtRepo.updateBalanceTx(txn, open.id, newBalance);
    });

    return txId;
  }

  Future<void> _applyStockAdjustments({
    required Transaction txn,
    required List<Map<String, Object?>> lines,
    required String? companyId,
    required String nowIso,
  }) async {
    if ((companyId ?? '').isEmpty) return;

    final Map<String, int> totalsByVariant = {};
    for (final e in lines) {
      final pid = e['productId']?.toString();
      final qty = (e['quantity'] as int?) ?? 0;
      if (pid == null || pid.isEmpty || qty <= 0) continue;
      totalsByVariant[pid] = (totalsByVariant[pid] ?? 0) + qty;
    }
    if (totalsByVariant.isEmpty) return;

    for (final entry in totalsByVariant.entries) {
      final pvId = entry.key;
      final qty = -entry.value;

      final row = await txn.rawQuery(
        'SELECT id FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1',
        [pvId, companyId],
      );

      if (row.isEmpty) {
        await txn.insert('stock_level', {
          'productVariantId': pvId,
          'companyId': companyId,
          'stockOnHand': 0,
          'stockAllocated': 0,
          'createdAt': nowIso,
          'updatedAt': nowIso,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await _upsertChangeLog(
          txn,
          'stock_level',
          '$pvId@$companyId',
          'INSERT',
          nowIso,
        );
      }

      await txn.rawUpdate(
        'UPDATE stock_level SET stockOnHand = COALESCE(stockOnHand,0) + ?, updatedAt=? WHERE productVariantId=? AND companyId=?',
        [qty, nowIso, pvId, companyId],
      );
      await _upsertChangeLog(
        txn,
        'stock_level',
        '$pvId@$companyId',
        'UPDATE',
        nowIso,
      );
    }
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
