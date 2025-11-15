// lib/infrastructure/debts/debt_repository_sqflite.dart
//
// Debt repository refactored to use ChangeTrackedExec helpers.
// - insertTracked / updateTracked centralize UTC timestamps, isDirty=1, version++,
//   and change_log upsert (PENDING).
// - Txn-aware methods kept (…Tx) and reused by non-txn variants.
// - "Open" debt is the row with statuses NULL or 'OPEN' (latest updatedAt).
//
import 'package:jaayko/sync/infrastructure/change_tracked_exec.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:jaayko/infrastructure/db/app_database.dart';
import 'package:jaayko/domain/debts/entities/debt.dart';
import 'package:jaayko/domain/debts/repositories/debt_repository.dart';

class DebtRepositorySqflite implements DebtRepository {
  final AppDatabase db;
  DebtRepositorySqflite(this.db);

  // ---------- Queries ----------

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
          'customerId = ? '
          'AND deletedAt IS NULL '
          'AND (statuses IS NULL OR statuses = ?)',
      whereArgs: [customerId, 'OPEN'],
      orderBy: 'datetime(updatedAt) DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Debt.fromMap(rows.first);
  }

  // ---------- Create ----------

  @override
  Future<Debt> create(Debt debt) async {
    Debt out = debt;
    await db.tx((txn) async {
      out = await createTx(txn, debt);
    });
    return out;
  }

  @override
  Future<Debt> createTx(Transaction txn, Debt debt) async {
    // insertTracked will set updatedAt (UTC), isDirty=1 and log into change_log.
    await txn.insertTracked('debt', debt.toMap(), operation: 'INSERT');
    // Optionally read back (ensures we return DB-authoritative timestamps).
    final row = await txn.query(
      'debt',
      where: 'id = ?',
      whereArgs: [debt.id],
      limit: 1,
    );
    return row.isNotEmpty ? Debt.fromMap(row.first) : debt;
  }

  // ---------- Balance updates ----------

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
    // updateTracked -> updatedAt=now(UTC), isDirty=1, version++, change_log upsert.
    await txn.updateTracked(
      'debt',
      {'balance': newBalance, 'balanceDebt': newBalance},
      where: 'id = ?',
      whereArgs: [id],
      entityId: id,
      operation: 'UPDATE',
    );
  }

  // ---------- Touch / mark updated ----------

  @override
  Future<void> markUpdated(String id, DateTime when) async {
    await db.tx((txn) async {
      await markUpdatedTx(txn, id, when);
    });
  }

  @override
  Future<void> markUpdatedTx(Transaction txn, String id, DateTime when) async {
    // We want to force a specific updatedAt; still leverage change-log + version++.
    await txn.updateTracked(
      'debt',
      {
        // ChangeTrackedExec will overwrite updatedAt with "now" by default.
        // If you really need to keep `when`, set it explicitly here:
        'updatedAt': when.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
      entityId: id,
      operation: 'UPDATE',
    );
  }

  // ---------- Ensure/open ----------

  @override
  Future<Debt> upsertOpenForCustomer(String customerId) async {
    Debt res = Debt.newOpenForCustomer(customerId);
    await db.tx((txn) async {
      res = await upsertOpenForCustomerTx(txn, customerId);
    });
    return res;
  }

  @override
  Future<Debt> upsertOpenForCustomerTx(
    Transaction txn,
    String customerId,
  ) async {
    final found = await findOpenByCustomerTx(txn, customerId);
    if (found != null) return found;

    final id = const Uuid().v4();
    final toInsert = {
      'id': id,
      'customerId': customerId,
      'balance': 0,
      'balanceDebt': 0,
      'statuses': 'OPEN',
      'version': 0,
      // createdAt/updatedAt/isDirty handled by insertTracked
    };

    await txn.insertTracked('debt', toInsert, operation: 'INSERT');

    final row = await txn.query(
      'debt',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return row.isNotEmpty
        ? Debt.fromMap(row.first)
        : Debt.newOpenForCustomer(customerId);
  }
}
