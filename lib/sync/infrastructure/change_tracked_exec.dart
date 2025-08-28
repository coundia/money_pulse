// Extension helpers to insert/update/soft-delete with auto-stamping and change_log upsert.
import 'package:sqflite/sqflite.dart';

import '../../infrastructure/db/account_stamp.dart';
import '../../sync/infrastructure/change_log_helper.dart';

String _nowIso() => DateTime.now().toUtc().toIso8601String();

extension ChangeTrackedExec on DatabaseExecutor {
  Future<int> insertTracked(
    String table,
    Map<String, Object?> values, {
    String idKey = 'id',
    String accountColumn = 'account',
    String? preferredAccountId,
    String? createdBy,
    String operation = 'INSERT',
  }) async {
    final stamped = await stampAccountIfMissing(
      this,
      values: {
        ...values,
        'createdAt': values['createdAt'] ?? _nowIso(),
        'updatedAt': _nowIso(),
        'isDirty': 1,
      },
      column: accountColumn,
      preferredAccountId: preferredAccountId,
    );

    print("*** to save stamped ****");
    print(stamped);

    final n = await insert(
      table,
      stamped,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    final entityId =
        (stamped[idKey] ?? stamped['localId'] ?? stamped['remoteId'])
            ?.toString() ??
        '';
    if (entityId.isNotEmpty) {
      await upsertChangeLogPending(
        this,
        entityTable: table,
        entityId: entityId,
        operation: operation,
        accountId: stamped[accountColumn]?.toString(),
        createdBy: createdBy,
      );
    }
    return n;
  }

  Future<int> updateTracked(
    String table,
    Map<String, Object?> values, {
    required String where,
    required List<Object?> whereArgs,
    required String entityId,
    String accountColumn = 'account',
    String? preferredAccountId,
    String? createdBy,
    String operation = 'UPDATE',
  }) async {
    final stamped = await stampAccountIfMissing(
      this,
      values: {...values, 'updatedAt': _nowIso(), 'isDirty': 1},
      column: accountColumn,
      preferredAccountId: preferredAccountId,
    );

    final n = await update(
      table,
      stamped,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    await rawUpdate(
      'UPDATE $table SET version=COALESCE(version,0)+1 WHERE id=?',
      [entityId],
    );

    await upsertChangeLogPending(
      this,
      entityTable: table,
      entityId: entityId,
      operation: operation,
      accountId: stamped[accountColumn]?.toString(),
      createdBy: createdBy,
    );

    return n;
  }

  Future<int> softDeleteTracked(
    String table, {
    required String entityId,
    String idColumn = 'id',
    String accountColumn = 'account',
    String? preferredAccountId,
    String? createdBy,
  }) async {
    final now = _nowIso();
    final n = await rawUpdate(
      'UPDATE $table SET deletedAt=?, isDirty=1, updatedAt=?, version=COALESCE(version,0)+1 WHERE $idColumn=?',
      [now, now, entityId],
    );

    await upsertChangeLogPending(
      this,
      entityTable: table,
      entityId: entityId,
      operation: 'DELETE',
      accountId: preferredAccountId,
      createdBy: createdBy,
    );

    return n;
  }
}
