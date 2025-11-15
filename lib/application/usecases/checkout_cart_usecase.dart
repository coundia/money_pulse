// lib/application/transactions/checkout_cart_usecase.dart
//
// Use case: create a transaction with items, optional debt linkage,
// stock movements, stock_level adjustments, and account / customer impacts.
//
// Notes:
// - Uses ChangeTrackedExec for tables that HAVE an `account` column
//   (transaction_item, stock_movement, stock_level). We KEEP manual writes
//   for tables without it (transaction_entry, account) to avoid regressions.
// - Still writes to change_log for all affected entities.
// - Preserves previous movement logic (DEBIT => stock IN, CREDIT/DEBT => stock OUT).
//
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';

import 'package:jaayko/infrastructure/db/app_database.dart';
import 'package:jaayko/domain/accounts/repositories/account_repository.dart';
import 'package:jaayko/domain/debts/entities/debt.dart';
import 'package:jaayko/domain/debts/repositories/debt_repository.dart';

import '../../sync/infrastructure/change_tracked_exec.dart'; // insertTracked / updateTracked / softDeleteTracked
import '../../sync/infrastructure/change_log_helper.dart'; // upsertChangeLogPending

class CheckoutCartUseCase {
  final AppDatabase db;
  final AccountRepository accountRepo;
  final DebtRepository debtRepo;
  CheckoutCartUseCase(this.db, this.accountRepo, this.debtRepo);

  Future<String> execute({
    required String
    typeEntry, // 'DEBIT' | 'CREDIT' | 'DEBT' | 'REMBOURSEMENT' | 'PRET'
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

    // We need an account for everything except DEBT (sale-on-debt)
    final needsAccount = (t != 'DEBT');
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

    final now = DateTime.now().toUtc();
    final date = (when ?? now).toUtc();
    final nowIso = now.toIso8601String();
    final txId = const Uuid().v4();

    await db.tx((txn) async {
      final resolvedCompany = await _resolveCompanyId(txn, companyId);

      // Debt envelope if needed
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

      // --- transaction_entry (no `account` column) -> keep manual insert + change_log
      await txn.insert('transaction_entry', {
        'id': txId,
        'remoteId': null,
        'localId': null,
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
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      await upsertChangeLogPending(
        txn,
        entityTable: 'transaction_entry',
        entityId: txId,
        operation: 'INSERT',
      );

      // --- Lines & movements
      final affectsStock = (t == 'DEBIT' || t == 'CREDIT' || t == 'DEBT');
      for (final l in lines) {
        final itemId = const Uuid().v4();
        final qty = asInt(l['quantity']);
        final up = asInt(l['unitPrice']);
        final safeQty = qty < 0 ? 0 : qty;
        final safeUp = up < 0 ? 0 : up;
        final tot = safeQty * safeUp;

        // transaction_item HAS an `account` column in your schema -> insertTracked OK
        await txn.insertTracked(
          'transaction_item',
          {
            'id': itemId,
            'transactionId': txId,
            'productId': l['productId'],
            'remoteId': null,
            'localId': null,
            'label': (l['label'] ?? '').toString(),
            'quantity': safeQty,
            'unitId': l['unitId'],
            'unitPrice': safeUp,
            'total': tot,
            'notes': null,
            'createdAt': nowIso,
            // updatedAt/isDirty handled by insertTracked
            'version': 0,
          },
          operation: 'INSERT',
          accountColumn: 'account', // this column exists on transaction_item
        );

        if (affectsStock) {
          final productIdStr = (l['productId']?.toString() ?? '');
          if (productIdStr.isNotEmpty &&
              safeQty > 0 &&
              (resolvedCompany ?? '').isNotEmpty) {
            final mvType = (t == 'DEBIT') ? 'IN' : 'OUT';

            // stock_movement HAS `account` column -> insertTracked OK
            final mvtId = const Uuid().v4();
            await txn.insertTracked(
              'stock_movement',
              {
                'id': mvtId,
                'type_stock_movement': mvType,
                'quantity': safeQty,
                'companyId': resolvedCompany,
                'productVariantId': productIdStr,
                'orderLineId': itemId,
                'discriminator': 'TXN',
                'createdAt': nowIso,
                // updatedAt/isDirty handled by insertTracked
                'syncAt': null,
                'version': 0,
                'remoteId': null,
                'localId': null,
              },
              operation: 'INSERT',
              accountColumn: 'account', // this column exists on stock_movement
            );
          }
        }
      }

      // --- Aggregate stock_level updates
      if (affectsStock) {
        await _applyStockAdjustments(
          txn: txn,
          typeEntry: t,
          lines: lines,
          companyId: resolvedCompany,
          nowIso: nowIso,
        );
      }

      // --- Debt side effects
      if ((isDebtAdd || isRepayment) &&
          openDebt != null &&
          customerId != null) {
        final debtDelta = isDebtAdd ? total : -total;
        final next = (openDebt.balance + debtDelta);
        final newDebtBalance = next < 0 ? 0 : next;

        await debtRepo.updateBalanceTx(txn, openDebt.id, newDebtBalance);

        await txn.rawUpdate(
          'UPDATE customer '
          'SET balanceDebt = CASE WHEN COALESCE(balanceDebt,0) + ? < 0 THEN 0 ELSE COALESCE(balanceDebt,0) + ? END, '
          'updatedAt = ?, isDirty = 1 '
          'WHERE id = ?',
          [debtDelta, debtDelta, nowIso, customerId],
        );
        await upsertChangeLogPending(
          txn,
          entityTable: 'customer',
          entityId: customerId,
          operation: 'UPDATE',
        );
      }

      // --- Customer balance side effects for normal transactions (no status)
      if (customerId != null &&
          (t == 'DEBIT' || t == 'CREDIT') &&
          status == null) {
        final balDelta = (t == 'CREDIT') ? total : -total;
        await txn.rawUpdate(
          'UPDATE customer '
          'SET balance = CASE WHEN COALESCE(balance,0) + ? < 0 THEN 0 ELSE COALESCE(balance,0) + ? END, '
          'updatedAt = ?, isDirty = 1 '
          'WHERE id = ?',
          [balDelta, balDelta, nowIso, customerId],
        );
        await upsertChangeLogPending(
          txn,
          entityTable: 'customer',
          entityId: customerId,
          operation: 'UPDATE',
        );
      }

      // --- Account balance (keep raw update to avoid stamping into wrong column)
      if (needsAccount && acc != null) {
        final delta = switch (t) {
          'DEBIT' => -total,
          'CREDIT' => total,
          'REMBOURSEMENT' => total,
          'PRET' => -total,
          _ => 0,
        };

        await txn.rawUpdate(
          '''
          UPDATE account
          SET
            balance_prev = COALESCE(balance, 0),
            balance      = COALESCE(balance, 0) + ?,
            updatedAt    = ?,
            isDirty      = 1,
            version      = COALESCE(version, 0) + 1
          WHERE id = ?
          ''',
          [delta, nowIso, acc.id],
        );
        await upsertChangeLogPending(
          txn,
          entityTable: 'account',
          entityId: acc.id,
          operation: 'UPDATE',
        );
      }
    });

    return txId;
  }

  // ---------------- helpers ----------------

  Future<void> _applyStockAdjustments({
    required Transaction txn,
    required String typeEntry,
    required List<Map<String, Object?>> lines,
    required String? companyId,
    required String nowIso,
  }) async {
    final company = (companyId ?? '');
    if (company.isEmpty) return;

    // sum qty per productVariantId
    final Map<String, int> totalsByVariant = {};
    int _asInt(Object? v) => (v is int) ? v : int.tryParse('${v ?? 0}') ?? 0;

    for (final l in lines) {
      final pid = l['productId']?.toString();
      final qty = _asInt(l['quantity']);
      if (pid == null || pid.isEmpty || qty <= 0) continue;
      totalsByVariant[pid] = (totalsByVariant[pid] ?? 0) + qty;
    }
    if (totalsByVariant.isEmpty) return;

    final sign = (typeEntry == 'DEBIT') ? 1 : -1; // DEBIT => IN, others => OUT

    for (final entry in totalsByVariant.entries) {
      final pvId = entry.key;
      final delta = entry.value * sign;

      // Ensure row exists
      final exists = await txn.rawQuery(
        'SELECT id FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1',
        [pvId, company],
      );

      if (exists.isEmpty) {
        // stock_level HAS `account` column -> insertTracked OK
        final id = const Uuid().v4();
        await txn.insertTracked(
          'stock_level',
          {
            'id': id,
            'productVariantId': pvId,
            'companyId': company,
            'stockOnHand': 0,
            'stockAllocated': 0,
            'createdAt': nowIso,
            // updatedAt/isDirty handled by insertTracked
            'version': 0,
          },
          operation: 'INSERT',
          accountColumn: 'account', // column exists on stock_level
        );
      }

      // Apply delta (clamped at 0)
      await txn.rawUpdate(
        'UPDATE stock_level '
        'SET stockOnHand = MAX(0, COALESCE(stockOnHand,0) + ?), updatedAt = ? '
        'WHERE productVariantId=? AND companyId=?',
        [delta, nowIso, pvId, company],
      );

      // Change-log for level row
      final idRow = await txn.rawQuery(
        'SELECT id FROM stock_level WHERE productVariantId=? AND companyId=? LIMIT 1',
        [pvId, company],
      );
      if (idRow.isNotEmpty) {
        await upsertChangeLogPending(
          txn,
          entityTable: 'stock_level',
          entityId: (idRow.first['id'] ?? '').toString(),
          operation: 'UPDATE',
        );
      }
    }
  }

  Future<String?> _resolveCompanyId(Transaction txn, String? provided) async {
    if (provided != null && provided.isNotEmpty) return provided;
    final def = await txn.rawQuery(
      'SELECT id FROM company WHERE isDefault=1 AND deletedAt IS NULL LIMIT 1',
    );
    return def.isEmpty ? null : (def.first['id'] as String?);
  }
}
