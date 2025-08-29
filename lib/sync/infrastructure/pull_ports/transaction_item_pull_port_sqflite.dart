// lib/sync/infrastructure/pull_ports/transaction_item_pull_port_sqflite.dart
//
// Sqflite pull port for transaction items with:
// - Pass 1: adopt remote ids using `localId` (never change PK `id`)
// - Pass 2: conflict-aware upsert
//   • Compare remote.syncAt vs local.updatedAt: keep newer
//   • When inserting and remoteId is NULL, set remoteId = id we insert
//   • Do NOT emit fake "force update" logs; insertion sets remoteId immediately

import 'package:sqflite/sqflite.dart';
import '../change_log_helper.dart';

typedef Json = Map<String, Object?>;

class TransactionItemPullPortSqflite {
  final Database db;
  TransactionItemPullPortSqflite(this.db);

  String get entityTable => 'transaction_item';

  // ---------- Helpers ----------
  int _asInt(Object? v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  String? _asStr(Object? v) => v?.toString();

  DateTime _asUtc(Object? v) {
    if (v == null) return DateTime.now().toUtc();
    final s = v.toString();
    final dt = DateTime.tryParse(s);
    return (dt?.toUtc() ?? DateTime.now().toUtc());
  }

  DateTime? _parseLocalDate(Object? v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    final norm = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(norm)?.toUtc();
  }

  // ---------- Pass 1: adopt remote ids (mapping only) ----------
  Future<int> adoptRemoteIds(List<Json> items) async {
    if (items.isEmpty) return 0;
    int changed = 0;

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = _asStr(r['id']) ?? _asStr(r['remoteId']);
        final localId = _asStr(r['localId']);
        if (remoteId == null || localId == null) continue;

        // 1) Local row by PK == localId ?
        final localRows = await txn.query(
          entityTable,
          where: 'id = ?',
          whereArgs: [localId],
          limit: 1,
        );

        if (localRows.isNotEmpty) {
          final local = localRows.first;
          final curRemote = _asStr(local['remoteId']);
          final curLocal = _asStr(local['localId']);

          // Already linked to this remote → skip
          if (curRemote == remoteId &&
              (curLocal == null || curLocal == localId) &&
              curRemote != null) {
            continue;
          }

          // Link (remoteId/localId)
          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId, 'isDirty': 1},
            where: 'id = ?',
            whereArgs: [localId],
          );

          await upsertChangeLogPending(
            txn,
            entityTable: entityTable,
            entityId: localId,
            operation: 'UPDATE',
          );

          // Remove duplicate row with PK == remoteId (keep local PK)
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

        // 2) Try row whose PK == remoteId
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

          // Identical mapping → skip
          if (curRemote == remoteId && curLocal == localId) {
            continue;
          }

          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId, 'isDirty': 1},
            where: 'id = ?',
            whereArgs: [remoteId],
          );

          await upsertChangeLogPending(
            txn,
            entityTable: entityTable,
            entityId: remoteId,
            operation: 'UPDATE',
          );

          changed++;
        }
        // else: nothing — insert handled in upsertRemote
      }
    });

    return changed;
  }

  // ---------- Pass 2: upsert ----------
  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(
    List<Json> items,
  ) async {
    if (items.isEmpty) return (upserts: 0, maxSyncAt: null);

    int upserts = 0;
    DateTime? maxAt;

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteIdIn = _asStr(r['id']) ?? _asStr(r['remoteId']);
        final localId = _asStr(r['localId']);
        final transaction =
            _asStr(r['transaction']) ?? _asStr(r['transactionId']);
        final productId = _asStr(r['productId']);
        final label = _asStr(r['label']);
        final unitId = _asStr(r['unitId']);
        final notes = _asStr(r['notes']);
        final quantity = _asInt(r['quantity']);
        final unitPrice = _asInt(r['unitPrice']);
        final total = _asInt(r['total']);

        final remoteSyncAt = _asUtc(r['syncAt']);
        if (maxAt == null || remoteSyncAt.isAfter(maxAt!)) maxAt = remoteSyncAt;

        // Base map for UPDATE (never include 'id' here)
        final base = <String, Object?>{
          'remoteId': remoteIdIn, // may be null; handled below
          'localId': localId,
          'transactionId': transaction,
          'productId': productId,
          'label': label,
          'unitId': unitId,
          'notes': notes,
          'quantity': quantity,
          'unitPrice': unitPrice,
          'total': total,
          'syncAt': remoteSyncAt.toIso8601String(),
        };

        // ---- Find local target row (without changing PK) ----
        Map<String, Object?>? target;
        if (remoteIdIn != null) {
          final t1 = await txn.query(
            entityTable,
            where: 'remoteId = ?',
            whereArgs: [remoteIdIn],
            limit: 1,
          );
          if (t1.isNotEmpty) target = t1.first;
          if (target == null) {
            final t2 = await txn.query(
              entityTable,
              where: 'id = ?',
              whereArgs: [remoteIdIn],
              limit: 1,
            );
            if (t2.isNotEmpty) target = t2.first;
          }
        }
        if (target == null && localId != null) {
          final t3 = await txn.query(
            entityTable,
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          if (t3.isNotEmpty) target = t3.first;
        }

        if (target != null) {
          // -------- UPDATE path --------
          final localUpdatedAt = _parseLocalDate(target['updatedAt']);
          final keepLocal =
              localUpdatedAt != null && localUpdatedAt.isAfter(remoteSyncAt);

          final merged = Map<String, Object?>.from(base);

          // Do NOT wipe an existing remoteId with null from server
          if (remoteIdIn == null) {
            merged['remoteId'] = target['remoteId'];
          }

          if (keepLocal) {
            merged['isDirty'] = target['isDirty'];
          } else {
            merged['isDirty'] = 0;
          }

          await txn.update(
            entityTable,
            merged,
            where: 'id = ?',
            whereArgs: [target['id']],
          );
          upserts++;
        } else {
          // -------- INSERT path --------
          final createdAt = remoteSyncAt.toIso8601String();

          // Choose PK to use; then if remoteId is null, set it to this PK before inserting
          final idToUse =
              remoteIdIn ??
              localId ??
              DateTime.now().microsecondsSinceEpoch.toString();

          final resolvedRemoteId = remoteIdIn ?? idToUse; // <— key change

          await txn.insert(entityTable, {
            'id': idToUse,
            ...base,
            'remoteId': resolvedRemoteId, // ensure not null on insert
            'createdAt': createdAt,
            'updatedAt': createdAt,
            'isDirty': 0,
          }, conflictAlgorithm: ConflictAlgorithm.abort);
          upserts++;

          //force update for next
          if (_asStr(r['remoteId']) == null) {
            await upsertChangeLogPending(
              txn,
              entityTable: entityTable,
              entityId: localId ?? '-',
              operation: 'UPDATE',
            );
          }
        }
      }
    });

    return (upserts: upserts, maxSyncAt: maxAt);
  }
}
