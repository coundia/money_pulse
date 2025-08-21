// Sqflite repository for accounts with change-log tracking and optional DatabaseExecutor for atomic operations.
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
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
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
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
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
    final rows = await _database.db.query(
      'account',
      where: 'isDefault=1 AND deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }

  @override
  Future<List<Account>> findAllActive() async {
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
            'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
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
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
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
        'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt, payload=excluded.payload',
        [idLog, 'account', id, 'DELETE', null, 'PENDING', nowIso, nowIso],
      );
    }

    if (exec != null) {
      await _do(exec);
    } else {
      await _database.tx((txn) async => _do(txn));
    }
  }
}
