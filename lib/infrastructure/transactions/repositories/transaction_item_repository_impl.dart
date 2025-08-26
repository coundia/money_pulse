import 'package:money_pulse/domain/transactions/entities/transaction_item.dart';
import 'package:money_pulse/domain/transactions/repositories/transaction_item_repository.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:sqflite/sqflite.dart';

import '../../../sync/infrastructure/change_log_helper.dart';

class TransactionItemRepositoryImpl implements TransactionItemRepository {
  final AppDatabase db;
  TransactionItemRepositoryImpl(this.db);

  @override
  Future<List<TransactionItem>> findByTransaction(String transactionId) async {
    return db.tx((txn) async {
      final rows = await txn.query(
        'transaction_item',
        where: 'transactionId=? AND deletedAt IS NULL',
        whereArgs: [transactionId],
        orderBy: 'createdAt ASC',
      );
      return rows.map((e) => TransactionItem.fromMap(e)).toList();
    });
  }

  @override
  Future<TransactionItem?> findById(String id) async {
    return db.tx((txn) async {
      final rows = await txn.query(
        'transaction_item',
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return TransactionItem.fromMap(rows.first);
    });
  }

  @override
  Future<String> create(TransactionItem item) async {
    final now = DateTime.now();
    final data = item
        .copyWith(
          total: item.quantity < 0 || item.unitPrice < 0
              ? 0
              : item.quantity * item.unitPrice,
          createdAt: item.createdAt,
          updatedAt: now,
          isDirty: true,
        )
        .toMap();
    await db.tx((txn) async {
      await txn.insert(
        'transaction_item',
        data,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await upsertChangeLogPending(
        txn,
        entityTable: 'transaction_item',
        entityId: item.id,
        operation: 'INSERT',
      );
    });
    return item.id;
  }

  @override
  Future<void> update(TransactionItem item) async {
    final now = DateTime.now();
    final next = item.copyWith(
      total: item.quantity < 0 || item.unitPrice < 0
          ? 0
          : item.quantity * item.unitPrice,
      updatedAt: now,
      isDirty: true,
      version: item.version + 1,
    );
    await db.tx((txn) async {
      await txn.update(
        'transaction_item',
        next.toMap(),
        where: 'id=?',
        whereArgs: [item.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      await upsertChangeLogPending(
        txn,
        entityTable: 'transaction_item',
        entityId: item.id,
        operation: 'UPDATE',
      );
    });
  }

  @override
  Future<void> softDelete(String id, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    await db.tx((txn) async {
      await txn.update(
        'transaction_item',
        {
          'deletedAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'isDirty': 1,
        },
        where: 'id=?',
        whereArgs: [id],
      );

      await upsertChangeLogPending(
        txn,
        entityTable: 'transaction_item',
        entityId: id,
        operation: 'DELETE',
      );
    });
  }

  @override
  Future<void> softDeleteByTransaction(
    String transactionId, {
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    await db.tx((txn) async {
      await txn.update(
        'transaction_item',
        {
          'deletedAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'isDirty': 1,
        },
        where: 'transactionId=? AND deletedAt IS NULL',
        whereArgs: [transactionId],
      );
    });
  }
}
