// Sqflite repository using ChangeTrackedExec for insert/update/soft-delete with auditing and safe ordering.
import 'package:jaayko/sync/infrastructure/change_tracked_exec.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:jaayko/domain/accounts/entities/account_user.dart';
import 'package:jaayko/domain/accounts/repositories/account_user_repository.dart';

extension _RowRead on Map<String, Object?> {
  String? s(String k) => this[k]?.toString();
}

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
    bool hasDeletedAt = info.any((c) => (c['name'] as String?) == 'deletedAt');
    if (!hasIdentity) {
      await db.execute('ALTER TABLE account_users ADD COLUMN identity TEXT');
      hasIdentity = true;
    }
    if (!hasMessage) {
      await db.execute('ALTER TABLE account_users ADD COLUMN message TEXT');
    }
    if (!hasDeletedAt) {
      await db.execute('ALTER TABLE account_users ADD COLUMN deletedAt TEXT');
    }
    if (hasIdentifyLegacy && hasIdentity) {
      await db.execute(
        'UPDATE account_users SET identity = COALESCE(identity, identify) WHERE identify IS NOT NULL',
      );
    }
  }

  Future<String?> _accountIdFor(String id) async {
    final rows = await db.query(
      'account_users',
      columns: ['account'],
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first.s('account');
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
      id: id,
      invitedAt: now,
      createdAt: now,
      updatedAt: now,
      isDirty: 1,
      version: au.version + 1,
    );
    final map = patched.toMap()..putIfAbsent('id', () => id);
    await db.insertTracked(
      'account_users',
      map,
      idKey: 'id',
      accountColumn: 'account',
      preferredAccountId: patched.account,
      createdBy: patched.createdBy,
      operation: 'CREATE',
    );
  }

  @override
  Future<void> updateRole(String id, String role) async {
    await _ensureColumns();
    final accountId = await _accountIdFor(id);
    await db.updateTracked(
      'account_users',
      {'role': role},
      where: 'id=?',
      whereArgs: [id],
      entityId: id,
      accountColumn: 'account',
      preferredAccountId: accountId,
      createdBy: null,
      operation: 'UPDATE',
    );
  }

  @override
  Future<void> revoke(String id) async {
    await _ensureColumns();
    final accountId = await _accountIdFor(id);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.updateTracked(
      'account_users',
      {'status': 'REVOKED', 'revokedAt': nowIso},
      where: 'id=?',
      whereArgs: [id],
      entityId: id,
      accountColumn: 'account',
      preferredAccountId: accountId,
      createdBy: null,
      operation: 'UPDATE',
    );
  }

  @override
  Future<AccountUser> accept(String id, {DateTime? when}) async {
    await _ensureColumns();
    final accountId = await _accountIdFor(id);
    final t = (when ?? DateTime.now().toUtc()).toIso8601String();
    final n = await db.updateTracked(
      'account_users',
      {'status': 'ACCEPTED', 'acceptedAt': t},
      where: 'id=? AND (status IS NULL OR status="PENDING")',
      whereArgs: [id],
      entityId: id,
      accountColumn: 'account',
      preferredAccountId: accountId,
      createdBy: null,
      operation: 'UPDATE',
    );
    final row = await db.query(
      'account_users',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (row.isEmpty) {
      throw StateError('AccountUser not found');
    }
    if (n == 0 && (row.first['status'] as String?) == 'REVOKED') {
      throw StateError('Cannot accept a revoked invitation');
    }
    return AccountUser.fromMap(row.first);
  }

  @override
  Future<void> delete(String id) async {
    await _ensureColumns();
    final accountId = await _accountIdFor(id);
    await db.softDeleteTracked(
      'account_users',
      entityId: id,
      idColumn: 'id',
      accountColumn: 'account',
      preferredAccountId: accountId,
      createdBy: null,
    );
  }
}
