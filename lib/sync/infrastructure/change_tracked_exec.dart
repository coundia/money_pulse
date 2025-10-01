// Change-tracked insert/update/soft-delete helpers that stamp audit fields and append change_log entries;
// never updates primary key. Now column-safe: only writes columns that actually exist on the table.
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

import '../../infrastructure/db/account_stamp.dart';
import '../../sync/infrastructure/change_log_helper.dart';

String _nowIso() => DateTime.now().toUtc().toIso8601String();

/// Simple in-memory cache of table columns for this process.
final Map<String, Set<String>> _tableColumnsCache = {};

Future<Set<String>> _columnsOf(DatabaseExecutor db, String table) async {
  final hit = _tableColumnsCache[table];
  if (hit != null) return hit;

  // DatabaseExecutor has rawQuery in both Database and Transaction.
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  final cols = rows.map((r) => (r['name'] as String)).toSet();
  _tableColumnsCache[table] = cols;
  return cols;
}

Map<String, Object?> _onlyTableColumns(
  Map<String, Object?> source,
  Set<String> allowedCols,
) {
  return Map.fromEntries(
    source.entries.where((e) => allowedCols.contains(e.key)),
  );
}

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
    final cols = await _columnsOf(this, table);
    final hasAccountCol = cols.contains(accountColumn);

    // Base stamping (created/updated/isDirty)
    final base = {
      ...values,
      'createdAt': values['createdAt'] ?? _nowIso(),
      'updatedAt': _nowIso(),
      'isDirty': 1,
    };

    // Stamp account only if the table actually has that column
    final stamped = hasAccountCol
        ? await stampAccountIfMissing(
            this,
            values: base,
            column: accountColumn,
            preferredAccountId: preferredAccountId,
          )
        : base;

    // Keep only real columns for this table
    final data = _onlyTableColumns(stamped, cols);

    final n = await insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    final entityId =
        (data[idKey] ?? data['localId'] ?? data['remoteId'])?.toString() ?? '';

    if (entityId.isNotEmpty) {
      await upsertChangeLogPending(
        this,
        entityTable: table,
        entityId: entityId,
        operation: operation,
        accountId: hasAccountCol
            ? data[accountColumn]?.toString()
            : preferredAccountId,
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
    String idKey = 'id',
    String accountColumn = 'account',
    String? preferredAccountId,
    String? createdBy,
    String operation = 'UPDATE',
  }) async {
    final cols = await _columnsOf(this, table);
    final hasAccountCol = cols.contains(accountColumn);

    // Update timestamps/dirty
    final base = {...values, 'updatedAt': _nowIso(), 'isDirty': 1};

    final stamped = hasAccountCol
        ? await stampAccountIfMissing(
            this,
            values: base,
            column: accountColumn,
            preferredAccountId: preferredAccountId,
          )
        : base;

    // Never update the primary key and never write non-existent columns
    final withNoId = Map<String, Object?>.from(stamped)..remove(idKey);
    final data = _onlyTableColumns(withNoId, cols);

    final n = await update(
      table,
      data,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    // Bump version atomically
    await rawUpdate(
      'UPDATE $table SET version=COALESCE(version,0)+1 WHERE $idKey=?',
      [entityId],
    );

    await upsertChangeLogPending(
      this,
      entityTable: table,
      entityId: entityId,
      operation: operation,
      accountId: hasAccountCol
          ? (stamped[accountColumn]?.toString())
          : preferredAccountId,
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
      'UPDATE $table '
      'SET deletedAt=?, isDirty=1, updatedAt=?, version=COALESCE(version,0)+1 '
      'WHERE $idColumn=?',
      [now, now, entityId],
    );

    // We can’t know the row values here; use preferredAccountId (caller can pass it)
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
