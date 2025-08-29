/* Sqflite repository for AccountUser with invite/list/search/role/revoke/accept and change log. */
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/accounts/entities/account_user.dart';
import 'package:money_pulse/domain/accounts/repositories/account_user_repository.dart';

class AccountUserRepositorySqflite implements AccountUserRepository {
  final Database db;
  AccountUserRepositorySqflite(this.db);

  Future<void> _ensureColumns() async {
    final info = await db.rawQuery('PRAGMA table_info(account_users)');
    bool hasIdentity = info.any((c) => (c['name'] as String?) == 'identity');
    bool hasIdentifyLegacy = info.any(
      (c) => (c['name'] as String?) == 'identify',
    );
    bool hasMessage = info.any((c) => (c['name'] as String?) == 'message');

    if (!hasIdentity) {
      await db.execute('ALTER TABLE account_users ADD COLUMN identity TEXT');
      hasIdentity = true;
    }
    if (!hasMessage) {
      await db.execute('ALTER TABLE account_users ADD COLUMN message TEXT');
    }
    if (hasIdentifyLegacy && hasIdentity) {
      await db.execute(
        'UPDATE account_users SET identity = COALESCE(identity, identify) WHERE identify IS NOT NULL',
      );
    }
  }

  @override
  Future<List<AccountUser>> listByAccount(String accountId, {String? q}) async {
    await _ensureColumns();
    final where = StringBuffer('account = ? AND deletedAt IS NULL');
    final args = <Object?>[accountId];
    if (q != null && q.trim().isNotEmpty) {
      final like = '%${q.toLowerCase()}%';
      where.write(
        ' AND (LOWER(COALESCE(identity,"")) LIKE ? OR LOWER(COALESCE(email,"")) LIKE ? OR LOWER(COALESCE(phone,"")) LIKE ? OR LOWER(COALESCE(user,"")) LIKE ?)',
      );
      args.addAll([like, like, like, like]);
    }
    final rows = await db.query(
      'account_users',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'COALESCE(updatedAt, createdAt, invitedAt) DESC',
    );
    return rows.map(AccountUser.fromMap).toList();
  }

  @override
  Future<void> invite(AccountUser au) async {
    await _ensureColumns();
    final id = au.id.isNotEmpty ? au.id : const Uuid().v4();
    final now = DateTime.now().toUtc();
    final patched = au.copyWith(
      invitedAt: now,
      createdAt: now,
      updatedAt: now,
      isDirty: 1,
      version: au.version + 1,
    );
    final map = patched.toMap()..putIfAbsent('id', () => id);
    await db.insert(
      'account_users',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _logChange(id, 'UPSERT');
  }

  @override
  Future<void> updateRole(String id, String role) async {
    await _ensureColumns();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawUpdate(
      'UPDATE account_users SET role=?, updatedAt=?, isDirty=1, version=COALESCE(version,0)+1 WHERE id=?',
      [role, now, id],
    );
    await _logChange(id, 'UPDATE');
  }

  @override
  Future<void> revoke(String id) async {
    await _ensureColumns();
    final now = DateTime.now().toUtc().toIso8601String();
    await db.rawUpdate(
      'UPDATE account_users SET status="REVOKED", revokedAt=?, updatedAt=?, isDirty=1, version=COALESCE(version,0)+1 WHERE id=?',
      [now, now, id],
    );
    await _logChange(id, 'UPDATE');
  }

  @override
  Future<AccountUser> accept(String id, {DateTime? when}) async {
    await _ensureColumns();
    final t = (when ?? DateTime.now().toUtc()).toIso8601String();
    final updated = await db.rawUpdate(
      'UPDATE account_users '
      'SET status="ACCEPTED", acceptedAt=?, updatedAt=?, isDirty=1, version=COALESCE(version,0)+1 '
      'WHERE id=? AND (status IS NULL OR status="PENDING")',
      [t, t, id],
    );
    await _logChange(id, 'UPDATE');
    final row = await db.query(
      'account_users',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (row.isEmpty) {
      throw StateError('AccountUser not found');
    }
    if (updated == 0 && (row.first['status'] as String?) == 'REVOKED') {
      throw StateError('Cannot accept a revoked invitation');
    }
    return AccountUser.fromMap(row.first);
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
