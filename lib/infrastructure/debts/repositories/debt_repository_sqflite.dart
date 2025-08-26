// Sqflite implementation using txn-aware methods through AppDatabase.tx.
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/debts/entities/debt.dart';
import 'package:money_pulse/domain/debts/repositories/debt_repository.dart';

import '../../../sync/infrastructure/change_log_helper.dart';

class DebtRepositorySqflite implements DebtRepository {
  final AppDatabase db;
  DebtRepositorySqflite(this.db);

  @override
  Future<Debt?> findOpenByCustomer(String customerId) async {
    Debt? result;
    await db.tx((txn) async {
      result = await findOpenByCustomerTx(txn, customerId);
    });
    return result;
  }

  @override
  Future<Debt?> findOpenByCustomerTx(Transaction txn, String customerId) async {
    final rows = await txn.query(
      'debt',
      where:
          'customerId = ? AND (deletedAt IS NULL) AND (statuses IS NULL OR statuses = ?)',
      whereArgs: [customerId, 'OPEN'],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Debt.fromMap(rows.first);
  }

  @override
  Future<Debt> create(Debt debt) async {
    await db.tx((txn) async {
      await createTx(txn, debt);
    });

    return debt;
  }

  @override
  Future<Debt> createTx(Transaction txn, Debt debt) async {
    await txn.insert('debt', debt.toMap());
    await upsertChangeLogPending(
      txn,
      entityTable: 'debt',
      entityId: debt.id,
      operation: 'INSERT',
    );
    return debt;
  }

  @override
  Future<void> updateBalance(String id, int newBalance) async {
    await db.tx((txn) async {
      await updateBalanceTx(txn, id, newBalance);
    });
  }

  @override
  Future<void> updateBalanceTx(
    Transaction txn,
    String id,
    int newBalance,
  ) async {
    final now = DateTime.now().toIso8601String();
    await txn.update(
      'debt',
      {
        'balance': newBalance,
        'balanceDebt': newBalance,
        'updatedAt': now,
        'isDirty': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await upsertChangeLogPending(
      txn,
      entityTable: 'debt',
      entityId: id,
      operation: 'UPDATE',
    );
  }

  @override
  Future<void> markUpdated(String id, DateTime when) async {
    await db.tx((txn) async {
      await markUpdatedTx(txn, id, when);
    });
  }

  @override
  Future<void> markUpdatedTx(Transaction txn, String id, DateTime when) async {
    await txn.update(
      'debt',
      {'updatedAt': when.toIso8601String(), 'isDirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );

    await upsertChangeLogPending(
      txn,
      entityTable: 'debt',
      entityId: id,
      operation: 'UPDATE',
    );
  }

  @override
  Future<Debt> upsertOpenForCustomer(String customerId) async {
    Debt? res;
    await db.tx((txn) async {
      res = await upsertOpenForCustomerTx(txn, customerId);
    });
    return res!;
  }

  @override
  Future<Debt> upsertOpenForCustomerTx(
    Transaction txn,
    String customerId,
  ) async {
    final found = await findOpenByCustomerTx(txn, customerId);
    if (found != null) return found;
    final created = Debt.newOpenForCustomer(customerId);
    await createTx(txn, created);
    return created;
  }
}
