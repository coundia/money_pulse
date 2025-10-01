// Sqflite repository for accounts using ChangeTrackedExec to auto-stamp and log changes; keeps balance_prev in sync and self-heals a single default within user scope.
import 'package:money_pulse/sync/infrastructure/change_tracked_exec.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';

typedef CurrentUserId = String? Function();

class AccountRepositorySqflite implements AccountRepository {
  final AppDatabase _database;
  final CurrentUserId? getUserId;

  AccountRepositorySqflite(this._database, {this.getUserId});

  String _nowIso() => DateTime.now().toIso8601String();

  ({String where, List<Object?> args}) _scopeWhere(String base, String? uid) {
    if (uid == null) {
      return (where: '$base AND createdBy IS NULL', args: const []);
    }
    return (
      where: '$base AND (createdBy IS NULL OR createdBy = ?)',
      args: [uid],
    );
  }

  @override
  Future<Account> create(Account account, {DatabaseExecutor? exec}) async {
    final now = DateTime.now();
    final a = account.copyWith(updatedAt: now, version: 0, isDirty: true);
    final uid = getUserId?.call();

    print("## create ###");

    Future<void> _do(DatabaseExecutor e) async {
      await e.insertTracked(
        'account',
        a.toMap(),
        idKey: 'id',
        accountColumn: 'id',
        createdBy: uid,
        operation: 'INSERT',
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
    print("## create ###");

    final now = DateTime.now();
    final a = account.copyWith(
      updatedAt: now,
      version: account.version + 1,
      isDirty: true,
    );
    final uid = getUserId?.call();

    Future<void> _do(DatabaseExecutor e) async {
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
          final values = a.toMap();
          if (currentBalance != a.balance) {
            values['balance_prev'] = currentBalance;
          }
          await e.updateTracked(
            'account',
            values,
            where: 'id=?',
            whereArgs: [a.id],
            entityId: a.id,
            accountColumn: 'id',
            createdBy: uid,
            operation: 'UPDATE',
          );
          return;
        }
      } catch (_) {}
      await e.updateTracked(
        'account',
        a.toMap(),
        where: 'id=?',
        whereArgs: [a.id],
        entityId: a.id,
        accountColumn: 'id',
        createdBy: uid,
        operation: 'UPDATE',
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
    await _ensureSingleDefault();
    final uid = getUserId?.call();
    final s = _scopeWhere('isDefault=1 AND deletedAt IS NULL', uid);
    final rows = await _database.db.query(
      'account',
      where: s.where,
      whereArgs: s.args.isEmpty ? null : s.args,
      orderBy: 'updatedAt DESC, createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }

  @override
  Future<List<Account>> findAllActive() async {
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
    final uid = getUserId?.call();

    Future<void> _do(DatabaseExecutor e) async {
      final prevScope = _scopeWhere('isDefault=1 AND deletedAt IS NULL', uid);
      final prev = await e.query(
        'account',
        columns: ['id'],
        where: prevScope.where,
        whereArgs: prevScope.args.isEmpty ? null : prevScope.args,
        limit: 1,
      );

      if (prev.isNotEmpty) {
        final prevId = prev.first['id'] as String;
        if (prevId != id) {
          await e.updateTracked(
            'account',
            {'isDefault': 0},
            where: 'id=?',
            whereArgs: [prevId],
            entityId: prevId,
            accountColumn: 'id',
            createdBy: uid,
            operation: 'UPDATE',
          );
        }
      }

      await e.updateTracked(
        'account',
        {'isDefault': 1},
        where: 'id=?',
        whereArgs: [id],
        entityId: id,
        accountColumn: 'id',
        createdBy: uid,
        operation: 'UPDATE',
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
    final uid = getUserId?.call();

    Future<void> _do(DatabaseExecutor e) async {
      await e.softDeleteTracked(
        'account',
        entityId: id,
        idColumn: 'id',
        accountColumn: 'id',
        createdBy: uid,
      );
    }

    if (exec != null) {
      await _do(exec);
    } else {
      await _database.tx((txn) async => _do(txn));
    }
  }

  @override
  Future<void> updateBalancesWithPrev(
    String id,
    int newBalanceCents, {
    DatabaseExecutor? exec,
  }) async {
    final uid = getUserId?.call();

    Future<void> _do(DatabaseExecutor e) async {
      final rows = await e.query(
        'account',
        columns: ['balance'],
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );
      final currentBalance = rows.isNotEmpty
          ? ((rows.first['balance'] as int?) ?? 0)
          : 0;
      await e.updateTracked(
        'account',
        {'balance_prev': currentBalance, 'balance': newBalanceCents},
        where: 'id=?',
        whereArgs: [id],
        entityId: id,
        accountColumn: 'id',
        createdBy: uid,
        operation: 'UPDATE',
      );
    }

    if (exec != null) {
      await _do(exec);
    } else {
      await _database.tx((txn) async => _do(txn));
    }
  }

  Future<void> _ensureSingleDefault({DatabaseExecutor? exec}) async {
    final uid = getUserId?.call();

    Future<void> _do(DatabaseExecutor e) async {
      final qDefaults = _scopeWhere('isDefault=1 AND deletedAt IS NULL', uid);
      final defaults = await e.query(
        'account',
        columns: ['id'],
        where: qDefaults.where,
        whereArgs: qDefaults.args.isEmpty ? null : qDefaults.args,
      );

      if (defaults.length > 1) {
        final winnerRows = await e.query(
          'account',
          columns: ['id'],
          where: qDefaults.where,
          whereArgs: qDefaults.args.isEmpty ? null : qDefaults.args,
          orderBy: 'updatedAt DESC, createdAt DESC',
          limit: 1,
        );
        if (winnerRows.isEmpty) return;
        final winnerId = winnerRows.first['id'] as String;

        final qLosers = _scopeWhere(
          'isDefault=1 AND deletedAt IS NULL AND id<>?',
          uid,
        );
        final losers = await e.query(
          'account',
          columns: ['id'],
          where: qLosers.where,
          whereArgs: [winnerId, ...qLosers.args],
        );

        for (final row in losers) {
          final loserId = row['id'] as String;
          await e.updateTracked(
            'account',
            {'isDefault': 0},
            where: 'id=?',
            whereArgs: [loserId],
            entityId: loserId,
            accountColumn: 'id',
            createdBy: uid,
            operation: 'UPDATE',
          );
        }
      } else if (defaults.isEmpty) {
        final qPick = _scopeWhere('deletedAt IS NULL', uid);
        final winnerRows = await e.query(
          'account',
          columns: ['id'],
          where: qPick.where,
          whereArgs: qPick.args.isEmpty ? null : qPick.args,
          orderBy: 'updatedAt DESC, createdAt DESC',
          limit: 1,
        );
        if (winnerRows.isEmpty) return;
        final winnerId = winnerRows.first['id'] as String;

        await e.updateTracked(
          'account',
          {'isDefault': 1},
          where: 'id=?',
          whereArgs: [winnerId],
          entityId: winnerId,
          accountColumn: 'id',
          createdBy: uid,
          operation: 'UPDATE',
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
