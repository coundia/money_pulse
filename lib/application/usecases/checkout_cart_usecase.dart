// Use case creating a transaction with stock and optional debt linkage; updates customer balance and balanceDebt accordingly.
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';
import 'package:money_pulse/domain/debts/entities/debt.dart';
import 'package:money_pulse/domain/debts/repositories/debt_repository.dart';

class CheckoutCartUseCase {
  final AppDatabase db;
  final AccountRepository accountRepo;
  final DebtRepository debtRepo;
  CheckoutCartUseCase(this.db, this.accountRepo, this.debtRepo);

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
    const allowed = {'DEBIT', 'CREDIT', 'DEBT', 'REMBOURSEMENT', 'PRET'};
    if (!allowed.contains(t)) {
      throw ArgumentError.value(
        typeEntry,
        'typeEntry',
        "must be one of $allowed",
      );
    }
    if (lines.isEmpty) {
      throw ArgumentError('lines cannot be empty');
    }

    int asInt(Object? v) => (v is int) ? v : int.tryParse('${v ?? 0}') ?? 0;

    final isDebtAdd = t == 'DEBT';
    final isRepayment = t == 'REMBOURSEMENT';
    if ((isDebtAdd || isRepayment) &&
        (customerId == null || customerId.isEmpty)) {
      throw StateError('customerId is required for $t');
    }

    final needsAccount = !(t == 'DEBT');
    final acc = needsAccount
        ? (accountId != null
              ? await accountRepo.findById(accountId)
              : await accountRepo.findDefault())
        : null;
    if (needsAccount && acc == null) {
      throw StateError('No default account found');
    }

    final total = lines.fold<int>(0, (p, e) {
      final q = asInt(e['quantity']);
      final up = asInt(e['unitPrice']);
      return p + (q < 0 ? 0 : q) * (up < 0 ? 0 : up);
    });

    final now = DateTime.now();
    final date = when ?? now;
    final nowIso = now.toIso8601String();
    final txId = const Uuid().v4();

    await db.tx((txn) async {
      final resolvedCompany = await _resolveCompanyId(txn, companyId);

      Debt? openDebt;
      if (isDebtAdd || isRepayment) {
        openDebt = await debtRepo.upsertOpenForCustomerTx(txn, customerId!);
      }

      final status = switch (t) {
        'DEBT' => 'DEBT',
        'REMBOURSEMENT' => 'REPAYMENT',
        'PRET' => 'LOAN',
        _ => null,
      };

      await txn.insert('transaction_entry', {
        'id': txId,
        'remoteId': null,
        'code': null,
        'description': description,
        'amount': total,
        'typeEntry': t,
        'dateTransaction': date.toIso8601String(),
        'status': status,
        'entityName': (customerId == null) ? null : 'CUSTOMER',
        'entityId': customerId,
        'accountId': acc?.id,
        'categoryId': categoryId,
        'companyId': resolvedCompany,
        'customerId': customerId,
        'debtId': openDebt?.id,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'deletedAt': null,
        'syncAt': null,
        'version': 0,
        'isDirty': 1,
      });

      final affectsStock = t == 'DEBIT' || t == 'CREDIT' || t == 'DEBT';
      for (final l in lines) {
        final itemId = const Uuid().v4();
        final qty = asInt(l['quantity']);
        final up = asInt(l['unitPrice']);
        final safeQty = qty < 0 ? 0 : qty;
        final safeUp = up < 0 ? 0 : up;
        final tot = safeQty * safeUp;

        await txn.insert('transaction_item', {
          'id': itemId,
          'transactionId': txId,
          'productId': l['productId'],
          'label': (l['label'] ?? '').toString(),
          'quantity': safeQty,
          'unitId': l['unitId'],
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

        if (affectsStock) {
          final productIdStr = (l['productId']?.toString() ?? '');
          if (productIdStr.isNotEmpty &&
              safeQty > 0 &&
              (resolvedCompany ?? '').isNotEmpty) {
            final mvType = (t == 'DEBIT') ? 'IN' : 'OUT';
            final movementId = await txn.insert('stock_movement', {
              'type_stock_movement': mvType,
              'quantity': safeQty,
              'companyId': resolvedCompany,
              'productVariantId': productIdStr,
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
      }

      if (affectsStock) {
        await _applyStockAdjustments(
          txn: txn,
          typeEntry: t,
          lines: lines,
          companyId: resolvedCompany,
          nowIso: nowIso,
        );
      }

      if ((isDebtAdd || isRepayment) &&
          openDebt != null &&
          customerId != null) {
        final debtDelta = isDebtAdd ? total : -total;
        final newDebtBalance = (openDebt.balance + debtDelta) < 0
            ? 0
            : (openDebt.balance + debtDelta);
        await debtRepo.updateBalanceTx(txn, openDebt.id, newDebtBalance);
        await _incCustomerBalanceDebtTx(txn, customerId, debtDelta, nowIso);
      }

      if (customerId != null &&
          (t == 'DEBIT' || t == 'CREDIT') &&
          status == null) {
        final balDelta = (t == 'CREDIT') ? total : -total;
        await _incCustomerBalanceTx(txn, customerId, balDelta, nowIso);
      }

      if (needsAccount) {
        final delta = switch (t) {
          'DEBIT' => -total,
          'CREDIT' => total,
          'REMBOURSEMENT' => total,
          'PRET' => -total,
          _ => 0,
        };
        await txn.rawUpdate(
          'UPDATE account SET balance = COALESCE(balance,0) + ?, updatedAt=?, isDirty=1, version=COALESCE(version,0)+1 WHERE id=?',
          [delta, nowIso, acc!.id],
        );
      }

      await _upsertChangeLog(txn, 'transaction_entry', txId, 'INSERT', nowIso);
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

    final sign = (typeEntry == 'DEBIT') ? 1 : -1;

    for (final entry in totalsByVariant.entries) {
      final pvId = entry.key;
      final qty = entry.value * sign;

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
    if (provided != null && provided.isNotEmpty) return provided;
    final def = await txn.rawQuery(
      'SELECT id FROM company WHERE isDefault=1 AND deletedAt IS NULL LIMIT 1',
    );
    return def.isEmpty ? null : (def.first['id'] as String?);
  }

  Future<void> _incCustomerBalanceTx(
    Transaction txn,
    String customerId,
    int delta,
    String nowIso,
  ) async {
    await txn.rawUpdate(
      'UPDATE customer '
      'SET balance = CASE WHEN COALESCE(balance,0) + ? < 0 THEN 0 ELSE COALESCE(balance,0) + ? END, '
      'updatedAt = ?, isDirty = 1 '
      'WHERE id = ?',
      [delta, delta, nowIso, customerId],
    );
  }

  Future<void> _incCustomerBalanceDebtTx(
    Transaction txn,
    String customerId,
    int delta,
    String nowIso,
  ) async {
    await txn.rawUpdate(
      'UPDATE customer '
      'SET balanceDebt = CASE WHEN COALESCE(balanceDebt,0) + ? < 0 THEN 0 ELSE COALESCE(balanceDebt,0) + ? END, '
      'updatedAt = ?, isDirty = 1 '
      'WHERE id = ?',
      [delta, delta, nowIso, customerId],
    );
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
