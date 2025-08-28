// lib/infrastructure/transactions/transaction_item_repository_sqflite.dart
//
// TransactionItem repository refactored to use ChangeTrackedExec helpers.
// - insertTracked / updateTracked / softDeleteTracked centralize:
//   * UTC timestamps (updatedAt), isDirty=1
//   * version++ on UPDATE/DELETE
//   * change_log upsert (PENDING)
//   * optional account stamping via `account` column when present
// - Bulk soft delete by transaction also writes change_log per row.
//
import 'package:money_pulse/domain/transactions/entities/transaction_item.dart';
import 'package:money_pulse/domain/transactions/repositories/transaction_item_repository.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/sync/infrastructure/change_tracked_exec.dart';
import 'package:sqflite/sqflite.dart';

class TransactionItemRepositoryImpl implements TransactionItemRepository {
  final AppDatabase db;
  TransactionItemRepositoryImpl(this.db);

  int _safeTotal(int qty, int unitPrice) {
    final q = qty < 0 ? 0 : qty;
    final p = unitPrice < 0 ? 0 : unitPrice;
    return q * p;
  }

  // ---------- Reads ----------

  @override
  Future<List<TransactionItem>> findByTransaction(String transactionId) async {
    return db.tx((txn) async {
      final rows = await txn.query(
        'transaction_item',
        where: 'transactionId = ? AND deletedAt IS NULL',
        whereArgs: [transactionId],
        orderBy: 'createdAt ASC',
      );
      return rows.map(TransactionItem.fromMap).toList();
    });
  }

  @override
  Future<TransactionItem?> findById(String id) async {
    return db.tx((txn) async {
      final rows = await txn.query(
        'transaction_item',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return TransactionItem.fromMap(rows.first);
    });
  }

  // ---------- Writes (ChangeTrackedExec) ----------

  @override
  Future<String> create(TransactionItem item) async {
    final now = DateTime.now().toUtc();
    final data = item
        .copyWith(
          total: _safeTotal(item.quantity, item.unitPrice),
          createdAt: item.createdAt ?? now,
          updatedAt: now, // will be normalized by insertTracked
          isDirty: true,
          // version: keep as provided (often 0)
        )
        .toMap();

    await db.tx((txn) async {
      await txn.insertTracked(
        'transaction_item',
        data,
        operation: 'INSERT',
        // accountColumn: 'account', // if your table has it (schema shows it exists)
        // preferredAccountId / createdBy may be passed here if available
      );
    });
    return item.id;
  }

  @override
  Future<void> update(TransactionItem item) async {
    final next = item.copyWith(
      total: _safeTotal(item.quantity, item.unitPrice),
      isDirty: true,
      // updatedAt and version++ handled by updateTracked
    );

    await db.tx((txn) async {
      await txn.updateTracked(
        'transaction_item',
        next.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
        entityId: item.id,
        operation: 'UPDATE',
      );
    });
  }

  @override
  Future<void> softDelete(String id, {DateTime? at}) async {
    final when = (at ?? DateTime.now()).toUtc().toIso8601String();
    await db.tx((txn) async {
      // Marks deletedAt/updatedAt/isDirty + version++ + change_log
      await txn.softDeleteTracked('transaction_item', entityId: id);
      // Force provided timestamp (optional)
      await txn.updateTracked(
        'transaction_item',
        {'updatedAt': when},
        where: 'id = ?',
        whereArgs: [id],
        entityId: id,
        operation: 'UPDATE',
      );
    });
  }

  @override
  Future<void> softDeleteByTransaction(
    String transactionId, {
    DateTime? at,
  }) async {
    final when = (at ?? DateTime.now()).toUtc().toIso8601String();
    await db.tx((txn) async {
      // 1) Fetch active item ids for that transaction
      final rows = await txn.query(
        'transaction_item',
        columns: ['id'],
        where: 'transactionId = ? AND deletedAt IS NULL',
        whereArgs: [transactionId],
      );

      // 2) Soft-delete each one (ensures change_log per row)
      for (final r in rows) {
        final id = (r['id'] ?? '').toString();
        if (id.isEmpty) continue;

        await txn.softDeleteTracked('transaction_item', entityId: id);

        // optional: enforce provided timestamp
        await txn.updateTracked(
          'transaction_item',
          {'updatedAt': when},
          where: 'id = ?',
          whereArgs: [id],
          entityId: id,
          operation: 'UPDATE',
        );
      }
    });
  }
}
