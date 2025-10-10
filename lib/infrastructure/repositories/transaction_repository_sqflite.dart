// lib/infrastructure/transactions/transaction_repository_sqflite.dart
//
// Sqflite-backed transaction repository using ChangeTrackedExec helpers:
// - UTC timestamps
// - Balance math applied ONLY when status == COMPLETED
// - Proper undo/apply on UPDATE depending on status transition
// - Centralized change_log + version bump via insertTracked/updateTracked/softDeleteTracked
// - List queries ordered by updatedAt DESC
//
import 'package:sqflite/sqflite.dart';

import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/domain/transactions/repositories/transaction_repository.dart';

// extension with insertTracked / updateTracked / softDeleteTracked
import 'package:money_pulse/sync/infrastructure/change_tracked_exec.dart';

class TransactionRepositorySqflite implements TransactionRepository {
  final AppDatabase _db;
  TransactionRepositorySqflite(this._db);

  String _nowUtcIso() => DateTime.now().toUtc().toIso8601String();

  bool _isCompleted(String? status) =>
      (status ?? '').toUpperCase() == 'COMPLETED';

  /// DEBIT decreases balance; CREDIT increases balance (amount is cents, positive).
  int _signedAmount(String typeEntry, int amount) {
    return typeEntry.toUpperCase() == 'DEBIT' ? -amount : amount;
  }

  Future<void> _adjustAccount(
    Transaction txn, {
    required String accountId,
    required int delta,
  }) async {
    if (accountId.isEmpty || delta == 0) return;
    final now = _nowUtcIso();

    // Mark the account row as changed (logs + version++).
    await txn.updateTracked(
      'account',
      {'updatedAt': now}, // updateTracked stamps updatedAt/isDirty/version
      where: 'id=?',
      whereArgs: [accountId],
      entityId: accountId,
      operation: 'UPDATE',
    );

    // Arithmetic update (no extra changelog/version bump here).
    await txn.rawUpdate(
      'UPDATE account SET balance = COALESCE(balance,0) + ?, updatedAt=? WHERE id=?',
      [delta, now, accountId],
    );
  }

  @override
  Future<TransactionEntry> create(TransactionEntry e) async {
    final entry = e.copyWith(
      updatedAt: DateTime.now().toUtc(),
      version: 0, // server sync can reconcile later
      isDirty: true,
    );

    await _db.tx((txn) async {
      // Insert transaction (auto-stamp + changelog)
      await txn.insertTracked(
        'transaction_entry',
        entry.toMap(),
        operation: 'INSERT',
      );

      // APPLY ONLY IF COMPLETED
      if (_isCompleted(entry.status)) {
        final accId = entry.accountId ?? '';
        if (accId.isNotEmpty) {
          final delta = _signedAmount(entry.typeEntry, entry.amount);
          await _adjustAccount(txn, accountId: accId, delta: delta);
        }
      }
    });

    return entry;
  }

  @override
  Future<void> update(TransactionEntry next) async {
    await _db.tx((txn) async {
      final rows = await txn.query(
        'transaction_entry',
        where: 'id=?',
        whereArgs: [next.id],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final prev = TransactionEntry.fromMap(rows.first);

      final prevCompleted = _isCompleted(prev.status);
      final nextCompleted = _isCompleted(next.status);

      // ---- Balance adjustments according to status transitions ----
      // We first UNDO previous impact if it was completed,
      // then APPLY new impact if it is completed.
      if (prevCompleted) {
        final prevAcc = prev.accountId ?? '';
        if (prevAcc.isNotEmpty) {
          final undo = -_signedAmount(prev.typeEntry, prev.amount);
          await _adjustAccount(txn, accountId: prevAcc, delta: undo);
        }
      }
      if (nextCompleted) {
        final nextAcc = (next.accountId ?? '');
        if (nextAcc.isNotEmpty) {
          final apply = _signedAmount(next.typeEntry, next.amount);
          await _adjustAccount(txn, accountId: nextAcc, delta: apply);
        }
      }

      // ---- Persist transaction changes (auto version++ & changelog) ----
      final updated = next.copyWith(
        updatedAt: DateTime.now().toUtc(),
        isDirty: true,
        createdAt: prev.createdAt,
      );

      final map = updated.toMap()..remove('version');
      await txn.updateTracked(
        'transaction_entry',
        map,
        where: 'id=?',
        whereArgs: [updated.id],
        entityId: updated.id,
        operation: 'UPDATE',
      );
    });
  }

  @override
  Future<void> softDelete(String id) async {
    await _db.tx((txn) async {
      final rows = await txn.query(
        'transaction_entry',
        where: 'id=? AND deletedAt IS NULL',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final entry = TransactionEntry.fromMap(rows.first);

      // If it impacted balance (COMPLETED), revert before delete.
      if (_isCompleted(entry.status)) {
        final accId = entry.accountId ?? '';
        if (accId.isNotEmpty) {
          final revert = -_signedAmount(entry.typeEntry, entry.amount);
          await _adjustAccount(txn, accountId: accId, delta: revert);
        }
      }

      // Mark deleted (auto changelog)
      await txn.softDeleteTracked('transaction_entry', entityId: id);
    });
  }

  @override
  Future<TransactionEntry?> findById(String id) async {
    final rows = await _db.db.query(
      'transaction_entry',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TransactionEntry.fromMap(rows.first);
  }

  @override
  Future<List<TransactionEntry>> findRecentByAccount(
    String accountId, {
    int limit = 50,
  }) async {
    final rows = await _db.db.query(
      'transaction_entry',
      where: 'accountId=? AND deletedAt IS NULL',
      whereArgs: [accountId],
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map(TransactionEntry.fromMap).toList();
  }

  @override
  Future<List<TransactionEntry>> findByAccountForMonth(
    String accountId,
    DateTime month, {
    String? typeEntry,
  }) async {
    final start = DateTime.utc(month.year, month.month, 1).toIso8601String();
    final end =
        (month.month == 12
                ? DateTime.utc(month.year + 1, 1, 1)
                : DateTime.utc(month.year, month.month + 1, 1))
            .toIso8601String();

    final where = StringBuffer(
      'accountId=? AND deletedAt IS NULL '
      'AND dateTransaction >= ? AND dateTransaction < ?',
    );
    final args = <Object?>[accountId, start, end];

    if (typeEntry != null) {
      where.write(' AND typeEntry = ?');
      args.add(typeEntry);
    }

    final rows = await _db.db.query(
      'transaction_entry',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'updatedAt DESC',
    );
    return rows.map(TransactionEntry.fromMap).toList();
  }

  @override
  Future<List<TransactionEntry>> findByAccountBetween(
    String accountId,
    DateTime from,
    DateTime to, {
    String? typeEntry,
  }) async {
    final fromIso = from.toUtc().toIso8601String();
    final toIso = to.toUtc().toIso8601String();

    final where = StringBuffer(
      '(accountId = ? OR (accountId IS NULL)) '
      'AND deletedAt IS NULL '
      'AND dateTransaction >= ? '
      'AND dateTransaction < ?',
    );
    final args = <Object?>[accountId, fromIso, toIso];

    if (typeEntry != null) {
      where.write(' AND typeEntry = ?');
      args.add(typeEntry);
    }

    final rows = await _db.db.query(
      'transaction_entry',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'updatedAt DESC',
    );
    return rows.map(TransactionEntry.fromMap).toList();
  }
}
