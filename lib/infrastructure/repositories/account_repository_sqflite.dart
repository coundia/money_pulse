// Sqflite repository for accounts with change-log tracking and optional DatabaseExecutor for atomic operations.
// Also ensures balance_prev mirrors the previous balance whenever balance changes.
// Self-heals default account so exactly one row isDefault=1 (never 0, never >1).
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';

class AccountRepositorySqflite implements AccountRepository {
  final AppDatabase _database;
  AccountRepositorySqflite(this._database);

  String _nowIso() => DateTime.now().toIso8601String();

  @override
  Future<Account> create(Account account, {DatabaseExecutor? exec}) async {
    final now = DateTime.now();
    final a = account.copyWith(updatedAt: now, version: 0, isDirty: true);

    Future<void> _do(DatabaseExecutor e) async {
      await e.insert(
        'account',
        a.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      final idLog = const Uuid().v4();
      await e.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [
          idLog,
          'account',
          a.id,
          'INSERT',
          null,
          'PENDING',
          _nowIso(),
          _nowIso(),
        ],
      );
    }

    if (exec != null) {
      await _do(exec);
    } else {
      await _database.tx((txn) async => _do(txn));
    }
    return a;
  }

  @override
  Future<void> update(Account account, {DatabaseExecutor? exec}) async {
    final now = DateTime.now();
    final a = account.copyWith(
      updatedAt: now,
      version: account.version + 1,
      isDirty: true,
    );

    Future<void> _do(DatabaseExecutor e) async {
      // If the balance is changing, snapshot current balance into balance_prev first.
      try {
        final rows = await e.query(
          'account',
          columns: ['balance'],
          where: 'id=?',
          whereArgs: [a.id],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final currentBalance = (rows.first['balance'] as int?) ?? 0;
          if (currentBalance != a.balance) {
            await e.rawUpdate(
              'UPDATE account SET balance_prev = COALESCE(balance,0) WHERE id=?',
              [a.id],
            );
          }
        }
      } catch (_) {
        // best-effort; if it fails we still proceed with the normal update
      }

      await e.update(
        'account',
        a.toMap(),
        where: 'id=?',
        whereArgs: [a.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final idLog = const Uuid().v4();
      await e.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [
          idLog,
          'account',
          a.id,
          'UPDATE',
          null,
          'PENDING',
          _nowIso(),
          _nowIso(),
        ],
      );
    }

    if (exec != null) {
      await _do(exec);
    } else {
      await _database.tx((txn) async => _do(txn));
    }
  }

  @override
  Future<Account?> findById(String id) async {
    final rows = await _database.db.query(
      'account',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }

  @override
  Future<Account?> findDefault() async {
    // Self-heal the default invariant before reading it.
    await _ensureSingleDefault();

    final rows = await _database.db.query(
      'account',
      where: 'isDefault=1 AND deletedAt IS NULL',
      orderBy: 'updatedAt DESC, createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }

  @override
  Future<List<Account>> findAllActive() async {
    // Self-heal here as well so UI always sees a single default.
    await _ensureSingleDefault();

    final rows = await _database.db.query(
      'account',
      where: 'deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
    );
    return rows.map(Account.fromMap).toList();
  }

  @override
  Future<void> setDefault(String id, {DatabaseExecutor? exec}) async {
    final nowIso = _nowIso();

    Future<void> _do(DatabaseExecutor e) async {
      final prev = await e.query(
        'account',
        columns: ['id'],
        where: 'isDefault=1 AND deletedAt IS NULL',
        limit: 1,
      );
      if (prev.isNotEmpty) {
        final prevId = prev.first['id'] as String;
        if (prevId != id) {
          await e.rawUpdate(
            'UPDATE account SET isDefault=0, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
            [nowIso, prevId],
          );
          final idLogPrev = const Uuid().v4();
          await e.rawInsert(
            'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
            'VALUES(?,?,?,?,?,?,?,?) '
            'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
            'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
            [
              idLogPrev,
              'account',
              prevId,
              'UPDATE',
              null,
              'PENDING',
              nowIso,
              nowIso,
            ],
          );
        }
      }

      await e.rawUpdate(
        'UPDATE account SET isDefault=1, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
        [nowIso, id],
      );
      final idLog = const Uuid().v4();
      await e.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'account', id, 'UPDATE', null, 'PENDING', nowIso, nowIso],
      );
    }

    if (exec != null) {
      await _do(exec);
    } else {
      await _database.tx((txn) async => _do(txn));
    }
  }

  @override
  Future<void> softDelete(String id, {DatabaseExecutor? exec}) async {
    final nowIso = _nowIso();

    Future<void> _do(DatabaseExecutor e) async {
      await e.rawUpdate(
        'UPDATE account SET deletedAt=?, isDirty=1, version=version+1, updatedAt=? WHERE id=?',
        [nowIso, nowIso, id],
      );
      final idLog = const Uuid().v4();
      await e.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'account', id, 'DELETE', null, 'PENDING', nowIso, nowIso],
      );
    }

    if (exec != null) {
      await _do(exec);
    } else {
      await _database.tx((txn) async => _do(txn));
    }
  }

  /// Optional helper if you want to adjust balances atomically from use cases:
  /// Sets balance_prev = current balance, then sets balance = newBalance.
  Future<void> updateBalancesWithPrev(
    String id,
    int newBalanceCents, {
    DatabaseExecutor? exec,
  }) async {
    final nowIso = _nowIso();

    Future<void> _do(DatabaseExecutor e) async {
      await e.rawUpdate(
        '''
        UPDATE account
        SET
          balance_prev = COALESCE(balance, 0),
          balance      = ?,
          updatedAt    = ?,
          isDirty      = 1,
          version      = COALESCE(version, 0) + 1
        WHERE id = ?
        ''',
        [newBalanceCents, nowIso, id],
      );

      final idLog = const Uuid().v4();
      await e.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) '
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
        'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'account', id, 'UPDATE', null, 'PENDING', nowIso, nowIso],
      );
    }

    if (exec != null) {
      await _do(exec);
    } else {
      await _database.tx((txn) async => _do(txn));
    }
  }

  // ------------------------- default self-heal --------------------------------

  /// Ensures exactly one default account (isDefault=1 and deletedAt IS NULL).
  /// If many defaults exist, keeps the most recently updated/created, clears others.
  /// If none exist (but accounts exist), promotes the most recent to default.
  Future<void> _ensureSingleDefault({DatabaseExecutor? exec}) async {
    Future<void> _do(DatabaseExecutor e) async {
      // Count current defaults (not deleted)
      final defaults = await e.query(
        'account',
        columns: ['id'],
        where: 'isDefault=1 AND deletedAt IS NULL',
      );

      final nowIso = _nowIso();

      if (defaults.length > 1) {
        // Winner: most recently updated (fallback created)
        final winnerRows = await e.rawQuery(
          'SELECT id FROM account '
          'WHERE isDefault=1 AND deletedAt IS NULL '
          'ORDER BY updatedAt DESC, createdAt DESC LIMIT 1',
        );
        if (winnerRows.isEmpty) return;
        final winnerId = winnerRows.first['id'] as String;

        // Losers: all other defaults
        final losers = await e.query(
          'account',
          columns: ['id'],
          where: 'isDefault=1 AND deletedAt IS NULL AND id<>?',
          whereArgs: [winnerId],
        );
        if (losers.isNotEmpty) {
          // Set others to 0; log each
          await e.rawUpdate(
            'UPDATE account SET isDefault=0, isDirty=1, version=version+1, updatedAt=? '
            'WHERE isDefault=1 AND deletedAt IS NULL AND id<>?',
            [nowIso, winnerId],
          );
          for (final row in losers) {
            final loserId = row['id'] as String;
            final idLog = const Uuid().v4();
            await e.rawInsert(
              'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
              'VALUES(?,?,?,?,?,?,?,?) '
              'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
              'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
              [
                idLog,
                'account',
                loserId,
                'UPDATE',
                null,
                'PENDING',
                nowIso,
                nowIso,
              ],
            );
          }
        }
      } else if (defaults.isEmpty) {
        // No default: promote the most recent active account (if any)
        final winnerRows = await e.rawQuery(
          'SELECT id FROM account '
          'WHERE deletedAt IS NULL '
          'ORDER BY updatedAt DESC, createdAt DESC LIMIT 1',
        );
        if (winnerRows.isEmpty) return; // no accounts
        final winnerId = winnerRows.first['id'] as String;

        await e.rawUpdate(
          'UPDATE account SET isDefault=1, isDirty=1, version=version+1, updatedAt=? '
          'WHERE id=?',
          [nowIso, winnerId],
        );
        final idLog = const Uuid().v4();
        await e.rawInsert(
          'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
          'VALUES(?,?,?,?,?,?,?,?) '
          'ON CONFLICT(entityTable, entityId, status) DO UPDATE '
          'SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
          [
            idLog,
            'account',
            winnerId,
            'UPDATE',
            null,
            'PENDING',
            nowIso,
            nowIso,
          ],
        );
      }
    }

    if (exec != null) {
      await _do(exec);
    } else {
      await _database.tx((txn) async => _do(txn));
    }
  }
}
