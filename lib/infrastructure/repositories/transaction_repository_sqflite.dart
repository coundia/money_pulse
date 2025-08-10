import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/domain/transactions/repositories/transaction_repository.dart';

class TransactionRepositorySqflite implements TransactionRepository {
  final AppDatabase _db;
  TransactionRepositorySqflite(this._db);

  String _now() => DateTime.now().toIso8601String();

  @override
  Future<TransactionEntry> create(TransactionEntry e) async {
    final entry = e.copyWith(
      updatedAt: DateTime.now(),
      version: 0,
      isDirty: true,
    );
    await _db.tx((txn) async {
      await txn.insert(
        'transaction_entry',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      if (entry.typeEntry == 'DEBIT') {
        await txn.rawUpdate(
          'UPDATE account SET balance=balance-?, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
          [entry.amount, _now(), entry.accountId],
        );
      } else {
        await txn.rawUpdate(
          'UPDATE account SET balance=balance+?, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
          [entry.amount, _now(), entry.accountId],
        );
      }
      final idLogTx = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [
          idLogTx,
          'transaction_entry',
          entry.id,
          'INSERT',
          null,
          'PENDING',
          _now(),
          _now(),
        ],
      );
      final idLogAcc = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [
          idLogAcc,
          'account',
          entry.accountId,
          'UPDATE',
          null,
          'PENDING',
          _now(),
          _now(),
        ],
      );
    });
    return entry;
  }

  @override
  Future<void> update(TransactionEntry entry) async {
    await _db.tx((txn) async {
      final rows = await txn.query(
        'transaction_entry',
        where: 'id=?',
        whereArgs: [entry.id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final old = TransactionEntry.fromMap(rows.first);
      final now = _now();

      if (old.accountId == entry.accountId) {
        int delta = 0;
        delta += old.typeEntry == 'DEBIT' ? old.amount : -old.amount;
        delta += entry.typeEntry == 'DEBIT' ? -entry.amount : entry.amount;
        if (delta != 0) {
          await txn.rawUpdate(
            'UPDATE account SET balance=balance+?, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
            [delta, now, entry.accountId],
          );
          final idLogAcc = const Uuid().v4();
          await txn.rawInsert(
            'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) VALUES(?,?,?,?,?,?,?,?) '
            'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
            [
              idLogAcc,
              'account',
              entry.accountId,
              'UPDATE',
              null,
              'PENDING',
              now,
              now,
            ],
          );
        }
      } else {
        final undoOld = old.typeEntry == 'DEBIT' ? old.amount : -old.amount;
        final applyNew = entry.typeEntry == 'DEBIT'
            ? -entry.amount
            : entry.amount;
        await txn.rawUpdate(
          'UPDATE account SET balance=balance+?, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
          [undoOld, now, old.accountId],
        );
        await txn.rawUpdate(
          'UPDATE account SET balance=balance+?, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
          [applyNew, now, entry.accountId],
        );
        final idLogAcc1 = const Uuid().v4();
        final idLogAcc2 = const Uuid().v4();
        await txn.rawInsert(
          'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) VALUES(?,?,?,?,?,?,?,?) '
          'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
          [
            idLogAcc1,
            'account',
            old.accountId,
            'UPDATE',
            null,
            'PENDING',
            now,
            now,
          ],
        );
        await txn.rawInsert(
          'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) VALUES(?,?,?,?,?,?,?,?) '
          'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
          [
            idLogAcc2,
            'account',
            entry.accountId,
            'UPDATE',
            null,
            'PENDING',
            now,
            now,
          ],
        );
      }

      final updated = entry.copyWith(
        updatedAt: DateTime.now(),
        version: old.version + 1,
        isDirty: true,
        createdAt: old.createdAt,
      );
      await txn.update(
        'transaction_entry',
        updated.toMap(),
        where: 'id=?',
        whereArgs: [entry.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final idLogTx = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [
          idLogTx,
          'transaction_entry',
          entry.id,
          'UPDATE',
          null,
          'PENDING',
          now,
          now,
        ],
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
      final now = _now();
      await txn.rawUpdate(
        'UPDATE transaction_entry SET deletedAt=?, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
        [now, now, id],
      );
      if (entry.typeEntry == 'DEBIT') {
        await txn.rawUpdate(
          'UPDATE account SET balance=balance+?, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
          [entry.amount, now, entry.accountId],
        );
      } else {
        await txn.rawUpdate(
          'UPDATE account SET balance=balance-?, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
          [entry.amount, now, entry.accountId],
        );
      }
      final idLogTx = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLogTx, 'transaction_entry', id, 'DELETE', null, 'PENDING', now, now],
      );
      final idLogAcc = const Uuid().v4();
      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [
          idLogAcc,
          'account',
          entry.accountId,
          'UPDATE',
          null,
          'PENDING',
          now,
          now,
        ],
      );
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
      orderBy: 'dateTransaction DESC, createdAt DESC',
      limit: limit,
    );
    return rows.map(TransactionEntry.fromMap).toList();
  }

  @override
  Future<List<Map<String, Object?>>> spendingByCategoryLast30Days(
    String accountId,
  ) async {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30)).toIso8601String();
    final rows = await _db.db.rawQuery(
      '''
      SELECT c.code AS categoryCode, SUM(t.amount) AS total
      FROM transaction_entry t
      LEFT JOIN category c ON c.id = t.categoryId
      WHERE t.accountId = ? AND t.deletedAt IS NULL AND t.typeEntry = 'DEBIT' AND t.dateTransaction >= ?
      GROUP BY c.code
      ORDER BY total DESC
    ''',
      [accountId, cutoff],
    );
    return rows;
  }
}
