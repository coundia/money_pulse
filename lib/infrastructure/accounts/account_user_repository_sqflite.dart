/* Sqflite repository for account_users with dirty flag and change_log writes. */
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/accounts/entities/account_user.dart';
import 'package:money_pulse/domain/accounts/repositories/account_user_repository.dart';

class AccountUserRepositorySqflite implements AccountUserRepository {
  final Database db;
  AccountUserRepositorySqflite(this.db);

  @override
  Future<List<AccountUser>> listByAccount(String accountId, {String? q}) async {
    final where = StringBuffer('account = ? AND deletedAt IS NULL');
    final args = <Object?>[accountId];
    if (q != null && q.trim().isNotEmpty) {
      where.write(
        ' AND (LOWER(COALESCE(email,"")) LIKE ? OR LOWER(COALESCE(phone,"")) LIKE ? OR LOWER(COALESCE(user,"")) LIKE ?)',
      );
      final like = '%${q.toLowerCase()}%';
      args.addAll([like, like, like]);
    }
    final rows = await db.query(
      'account_users',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'updatedAt DESC',
    );
    return rows.map(AccountUser.fromMap).toList();
  }

  @override
  Future<void> invite(AccountUser au) async {
    final id = au.id.isNotEmpty ? au.id : const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final map =
        au
            .copyWith(
              invitedAt: DateTime.now().toUtc(),
              createdAt: DateTime.now().toUtc(),
              updatedAt: DateTime.now().toUtc(),
              isDirty: 1,
              version: au.version + 1,
            )
            .toMap()
          ..putIfAbsent('id', () => id);
    await db.insert(
      'account_users',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _logChange(id, 'UPSERT');
  }

  @override
  Future<void> updateRole(String id, String role) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'account_users',
      {'role': role, 'updatedAt': now, 'isDirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _logChange(id, 'UPDATE');
  }

  @override
  Future<void> revoke(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'account_users',
      {'status': 'REVOKED', 'revokedAt': now, 'updatedAt': now, 'isDirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _logChange(id, 'UPDATE');
  }

  Future<void> _logChange(String entityId, String op) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final idLog = const Uuid().v4();
    await db.rawInsert(
      'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, attempts, createdAt, updatedAt) '
      'VALUES(?,?,?,?,?,?,0,?,?) '
      'ON CONFLICT(entityTable, entityId, status) DO UPDATE SET operation=excluded.operation, updatedAt=excluded.updatedAt',
      [idLog, 'account_users', entityId, op, null, 'PENDING', now, now],
    );
  }
}
