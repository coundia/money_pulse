/// Use case that creates a transaction with items and properly updates stock levels per product (TEXT id) and company in the same SQL transaction, with change_log entries.
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';

class CheckoutCartUseCase {
  final AppDatabase db;
  final AccountRepository accountRepo;
  CheckoutCartUseCase(this.db, this.accountRepo);

  Future<String> execute({
    required String typeEntry,
    String? accountId,
    String? categoryId,
    String? description,
    String? companyId,
    String? customerId,
    DateTime? when,
    required List<Map<String, Object?>> lines,
  }) async {
    final t = typeEntry.toUpperCase();
    if (t != 'CREDIT' && t != 'DEBIT') {
      throw ArgumentError.value(
        typeEntry,
        'typeEntry',
        "must be 'CREDIT' or 'DEBIT'",
      );
    }
    if (lines.isEmpty) {
      throw ArgumentError('lines cannot be empty');
    }

    int _asInt(Object? v) => (v is int) ? v : int.tryParse('${v ?? 0}') ?? 0;

    final acc = accountId != null
        ? await accountRepo.findById(accountId)
        : await accountRepo.findDefault();
    if (acc == null) {
      throw StateError('No default account found');
    }

    final total = lines.fold<int>(0, (p, e) {
      final q = _asInt(e['quantity']);
      final up = _asInt(e['unitPrice']);
      return p + (q < 0 ? 0 : q) * (up < 0 ? 0 : up);
    });

    final now = DateTime.now();
    final date = when ?? now;
    final txId = const Uuid().v4();

    await db.tx((txn) async {
      await txn.insert('transaction_entry', {
        'id': txId,
        'remoteId': null,
        'code': null,
        'description': description,
        'amount': total,
        'typeEntry': t,
        'dateTransaction': date.toIso8601String(),
        'status': null,
        'entityName': null,
        'entityId': null,
        'accountId': acc.id,
        'categoryId': categoryId,
        'companyId': companyId,
        'customerId': customerId,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'deletedAt': null,
        'syncAt': null,
        'version': 0,
        'isDirty': 1,
      });

      for (final l in lines) {
        final itemId = const Uuid().v4();
        final qty = _asInt(l['quantity']);
        final up = _asInt(l['unitPrice']);
        final tot = (qty < 0 ? 0 : qty) * (up < 0 ? 0 : up);
        await txn.insert('transaction_item', {
          'id': itemId,
          'transactionId': txId,
          'productId': l['productId'],
          'label': (l['label'] ?? '').toString(),
          'quantity': qty < 0 ? 0 : qty,
          'unitPrice': up < 0 ? 0 : up,
          'total': tot,
          'notes': null,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'deletedAt': null,
          'syncAt': null,
          'version': 0,
          'isDirty': 1,
        });
      }

      await _applyStockAdjustments(
        txn: txn,
        typeEntry: t,
        lines: lines,
        companyId: companyId,
        nowIso: now.toIso8601String(),
      );

      final newBalance = t == 'CREDIT'
          ? acc.balance + total
          : acc.balance - total;
      await txn.update(
        'account',
        {
          'balance': newBalance,
          'updatedAt': now.toIso8601String(),
          'isDirty': 1,
          'version': acc.version + 1,
        },
        where: 'id=?',
        whereArgs: [acc.id],
      );

      final idLog = const Uuid().v4();
      await txn.rawInsert(
        '''
        INSERT INTO change_log(
          id, entityTable, entityId, operation, payload, status, attempts, error, createdAt, updatedAt, processedAt
        )
        VALUES(?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(entityTable, entityId, status) DO UPDATE SET
          operation=excluded.operation,
          payload=excluded.payload,
          updatedAt=excluded.updatedAt
        ''',
        [
          idLog,
          'transaction_entry',
          txId,
          'INSERT',
          null,
          'PENDING',
          0,
          null,
          now.toIso8601String(),
          now.toIso8601String(),
          null,
        ],
      );
    });

    return txId;
  }

  Future<void> _applyStockAdjustments({
    required Transaction txn,
    required String typeEntry,
    required List<Map<String, Object?>> lines,
    required String? companyId,
    required String nowIso,
  }) async {
    String? company = companyId;
    if (company == null || company.isEmpty) {
      final def = await txn.rawQuery(
        "SELECT id FROM company WHERE isDefault=1 AND deletedAt IS NULL LIMIT 1",
      );
      company = def.isEmpty ? null : (def.first['id'] as String?);
    }
    if (company == null || company.isEmpty) return;

    final Map<String, int> totalsByVariant = {};
    for (final l in lines) {
      final pid = l['productId']?.toString();
      final qty = (l['quantity'] is int)
          ? l['quantity'] as int
          : int.tryParse('${l['quantity'] ?? 0}') ?? 0;
      if (pid == null || pid.isEmpty || qty <= 0) continue;
      totalsByVariant[pid] = (totalsByVariant[pid] ?? 0) + qty;
    }
    if (totalsByVariant.isEmpty) return;

    final sign = typeEntry == 'DEBIT' ? 1 : -1;

    for (final entry in totalsByVariant.entries) {
      final pvId = entry.key;
      final qty = entry.value * sign;

      final row = await txn.rawQuery(
        "SELECT id FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1",
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
        "UPDATE stock_level SET stockOnHand = COALESCE(stockOnHand,0) + ?, updatedAt=? WHERE productVariantId=? AND companyId=?",
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
