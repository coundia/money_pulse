// lib/sync/infrastructure/pull_ports/transaction_pull_port_sqflite.dart
//
// Sqflite pull port for transactions.
// Pass 1: adopt remote ids using `localId` (never change PK `id`; no change_log)
// Pass 2: upsert/merge fields with conflict resolution by timestamps:
//   • Compare remote.syncAt vs local.updatedAt
//     - If local is newer  → keep local fields and keep isDirty as-is
//     - If remote is newer → apply remote fields and set isDirty = 0
//   • Only log to change_log (via upsertChangeLogPending) when a material UPDATE
//     actually changes fields (no-op updates are not logged).
// INSERTs from remote do not create change_log entries.

import 'package:sqflite/sqflite.dart';
import '../change_log_helper.dart';

typedef Json = Map<String, Object?>;

class TransactionPullPortSqflite {
  final Database db;
  TransactionPullPortSqflite(this.db);

  String get entityTable => 'transaction_entry';

  // ---------- Helpers ----------
  String? _asStr(Object? v) => v?.toString();
  int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  DateTime _asUtc(Object? v) {
    if (v == null) return DateTime.now().toUtc();
    final dt = DateTime.tryParse(v.toString());
    return (dt?.toUtc() ?? DateTime.now().toUtc());
  }

  DateTime? _parseLocalDate(Object? v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    final norm = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(norm)?.toUtc();
  }

  bool _differs(
    Map<String, Object?> a,
    Map<String, Object?> b,
    Iterable<String> keys,
  ) {
    for (final k in keys) {
      final va = a[k];
      final vb = b[k];
      if ((va ?? '') != (vb ?? '')) return true;
    }
    return false;
  }

  // Only business fields; exclude ids/syncAt/updatedAt, etc.
  static const _materialKeys = <String>{
    'code',
    'description',
    'typeEntry',
    'amount',
    'accountId',
    'categoryId',
    'companyId',
    'customerId',
    'dateTransaction',
    'status',
  };

  // ---------- Pass 1: adopt remote ids (no change_log here) ----------
  Future<int> adoptRemoteIds(List<Json> items) async {
    if (items.isEmpty) return 0;
    int changed = 0;

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = _asStr(r['id']) ?? _asStr(r['remoteId']);
        final localId = _asStr(r['localId']);
        if (remoteId == null || localId == null) continue;

        // 1) Row with PK == localId ?
        final localRows = await txn.query(
          entityTable,
          where: 'id = ?',
          whereArgs: [localId],
          limit: 1,
        );
        if (localRows.isNotEmpty) {
          final row = localRows.first;
          final curRemote = _asStr(row['remoteId']);
          final curLocal = _asStr(row['localId']);

          // Already mapped → skip (don't touch change_log, don't set isDirty)
          if (curRemote == remoteId &&
              (curLocal == null || curLocal == localId)) {
            continue;
          }

          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId},
            where: 'id = ?',
            whereArgs: [localId],
          );

          // Remove duplicate with PK == remoteId (keep local PK)
          if (remoteId != localId) {
            final dup = await txn.query(
              entityTable,
              where: 'id = ?',
              whereArgs: [remoteId],
              limit: 1,
            );
            if (dup.isNotEmpty) {
              await txn.delete(
                entityTable,
                where: 'id = ?',
                whereArgs: [remoteId],
              );
            }
          }
          changed++;
          continue;
        }

        // 2) Else: row with PK == remoteId ?
        final remoteRows = await txn.query(
          entityTable,
          where: 'id = ?',
          whereArgs: [remoteId],
          limit: 1,
        );
        if (remoteRows.isNotEmpty) {
          final row = remoteRows.first;
          final curRemote = _asStr(row['remoteId']);
          final curLocal = _asStr(row['localId']);

          if (curRemote == remoteId && curLocal == localId) {
            continue;
          }

          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId},
            where: 'id = ?',
            whereArgs: [remoteId],
          );
          changed++;
        }
        // else: insert will be handled in upsertRemote
      }
    });

    return changed;
  }

  // ---------- Pass 2: upsert with conflict resolution ----------
  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(
    List<Json> items,
  ) async {
    if (items.isEmpty) return (upserts: 0, maxSyncAt: null);
    int upserts = 0;
    DateTime? maxAt;

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = _asStr(r['id']) ?? _asStr(r['remoteId']);
        final localId = _asStr(r['localId']);
        final code = _asStr(r['code']);
        final description = _asStr(r['description']);
        final typeEntry = _asStr(r['typeEntry']) ?? 'DEBIT';
        final amount = _asInt(r['amount']);
        final accountId = _asStr(r['account']) ?? _asStr(r['accountId']);
        final categoryId = _asStr(r['category']) ?? _asStr(r['categoryId']);
        final companyId = _asStr(r['company']) ?? _asStr(r['companyId']);
        final customerId = _asStr(r['customer']) ?? _asStr(r['customerId']);
        final dateTransaction = _asStr(r['dateTransaction']);
        final status = _asStr(r['status']);

        //force update for next, if remoteId is null
        if (_asStr(r['remoteId']) == null) {
          await upsertChangeLogPending(
            txn,
            entityTable: entityTable,
            entityId: localId ?? "-",
            operation: 'UPDATE',
          );
        }

        final remoteSyncAt = _asUtc(r['syncAt']);
        if (maxAt == null || remoteSyncAt.isAfter(maxAt!)) maxAt = remoteSyncAt;

        // Data to write on UPDATE (never include 'id' here)
        final baseData = <String, Object?>{
          'remoteId': remoteId,
          'localId': localId,
          'code': code,
          'description': description,
          'typeEntry': typeEntry,
          'amount': amount,
          'accountId': accountId,
          'categoryId': categoryId,
          'companyId': companyId,
          'customerId': customerId,
          'dateTransaction': dateTransaction,
          'status': status,
          'syncAt': remoteSyncAt.toIso8601String(),
          // Do NOT set updatedAt (reserved for local edits)
        };

        // ---- Locate target row (without changing PK) ----
        Map<String, Object?>? targetRow;
        if (remoteId != null) {
          final byRemoteId = await txn.query(
            entityTable,
            where: 'remoteId = ?',
            whereArgs: [remoteId],
            limit: 1,
          );
          if (byRemoteId.isNotEmpty) {
            targetRow = byRemoteId.first;
          } else {
            final byIdEqRemote = await txn.query(
              entityTable,
              where: 'id = ?',
              whereArgs: [remoteId],
              limit: 1,
            );
            if (byIdEqRemote.isNotEmpty) targetRow = byIdEqRemote.first;
          }
        }
        if (targetRow == null && localId != null) {
          final byLocalId = await txn.query(
            entityTable,
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          if (byLocalId.isNotEmpty) targetRow = byLocalId.first;
        }

        if (targetRow != null) {
          // -------- UPDATE path --------
          final localUpdatedAt = _parseLocalDate(targetRow['updatedAt']);
          final keepLocal =
              localUpdatedAt != null && localUpdatedAt.isAfter(remoteSyncAt);

          final merged = Map<String, Object?>.from(baseData);
          if (keepLocal) {
            // Keep all material fields and isDirty as-is
            for (final k in _materialKeys) {
              merged[k] = targetRow[k];
            }
            merged['isDirty'] = targetRow['isDirty'];
          } else {
            // Remote wins for material fields; mark clean
            merged['isDirty'] = 0;
          }

          // Determine if this update actually changes material fields
          final currentComparable = {
            for (final k in _materialKeys) k: targetRow[k],
          };
          final mergedComparable = {
            for (final k in _materialKeys) k: merged[k],
          };
          final willLog = _differs(
            currentComparable,
            mergedComparable,
            _materialKeys,
          );

          await txn.update(
            entityTable,
            merged,
            where: 'id = ?',
            whereArgs: [targetRow['id']],
          );

          if (willLog) {
            await upsertChangeLogPending(
              txn,
              entityTable: entityTable,
              entityId: (targetRow['id'] ?? localId ?? remoteId).toString(),
              operation: 'UPDATE',
            );
          }

          upserts++;
        } else {
          // -------- INSERT path (new row from remote) --------
          final createdAt = remoteSyncAt.toIso8601String();
          final idToUse =
              localId ??
              remoteId ??
              DateTime.now().microsecondsSinceEpoch.toString();

          await txn.insert(entityTable, {
            'id': idToUse,
            ...baseData,
            'createdAt': createdAt,
            'updatedAt': createdAt,
            'isDirty': 0,
          }, conflictAlgorithm: ConflictAlgorithm.abort);

          // No change_log on INSERT from remote
          upserts++;
        }
      }
    });

    return (upserts: upserts, maxSyncAt: maxAt);
  }
}
