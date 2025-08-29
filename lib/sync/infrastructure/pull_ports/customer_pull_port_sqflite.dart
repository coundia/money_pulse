// lib/sync/infrastructure/pull_ports/customer_pull_port_sqflite.dart
//
// Sqflite pull port for customers:
// - Pass 1: adopt remote ids using localId (never change PK `id`; no change_log)
// - Pass 2: upsert/merge fields
//     • Balance conflict: compare remote.syncAt vs local.updatedAt
//         - If local is newer → keep local balances & isDirty as-is
//         - If remote wins     → apply remote balances & set isDirty=0
//     • Only log UPDATEs to change_log via upsertChangeLogPending when
//       material fields actually change (no-op updates don't log)
// - INSERTs: considered remote source → no change_log entry; updatedAt=remote.syncAt

import 'package:sqflite/sqflite.dart';
import '../change_log_helper.dart';

typedef Json = Map<String, Object?>;

class CustomerPullPortSqflite {
  final Database db;
  CustomerPullPortSqflite(this.db);

  String get entityTable => 'customer';

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
    if (v is DateTime) return v.toUtc();
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
      if (va is String && vb is String) {
        if (va != vb) return true;
      } else {
        if ((va ?? '') != (vb ?? '')) return true;
      }
    }
    return false;
  }

  static const _materialKeys = <String>{
    'remoteId',
    'localId',
    'code',
    'firstName',
    'lastName',
    'fullName',
    'phone',
    'email',
    'notes',
    'status',
    'companyId',
    'addressLine1',
    'addressLine2',
    'city',
    'region',
    'country',
    'postalCode',
    'balance',
    'balanceDebt',
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

          // Already mapped → skip
          if (curRemote == remoteId &&
              (curLocal == null || curLocal == localId)) {
            continue;
          }

          // Update linkage only; do not set isDirty or change_log
          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId},
            where: 'id = ?',
            whereArgs: [localId],
          );

          // Remove duplicate PK == remoteId (keep local PK)
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

        // 2) Otherwise: row with PK == remoteId ?
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

  // ---------- Pass 2: upsert with balance conflict resolution ----------
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
        final firstName = _asStr(r['firstName']);
        final lastName = _asStr(r['lastName']);
        final fullName = _asStr(r['fullName']);
        final phone = _asStr(r['phone']);
        final email = _asStr(r['email']);
        final notes = _asStr(r['notes']);
        final status = _asStr(r['status']);
        final companyId = _asStr(r['companyId']) ?? _asStr(r['company']);
        final address1 = _asStr(r['addressLine1']);
        final address2 = _asStr(r['addressLine2']);
        final city = _asStr(r['city']);
        final region = _asStr(r['region']);
        final country = _asStr(r['country']);
        final postalCode = _asStr(r['postalCode']);

        //force update for next
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

        final baseData = <String, Object?>{
          // No 'id' on UPDATE path
          'remoteId': remoteId,
          'localId': localId,
          'code': code,
          'firstName': firstName,
          'lastName': lastName,
          'fullName': fullName,
          'phone': phone,
          'email': email,
          'notes': notes,
          'status': status,
          'companyId': companyId,
          'addressLine1': address1,
          'addressLine2': address2,
          'city': city,
          'region': region,
          'country': country,
          'postalCode': postalCode,
          'syncAt': remoteSyncAt.toIso8601String(),
        };

        final remoteBalances = <String, Object?>{
          'balance': _asInt(r['balance']),
          'balanceDebt': _asInt(r['balanceDebt']),
        };

        // --- Locate target row (never change PK) ---
        Map<String, Object?>? targetRow;
        if (remoteId != null) {
          final byRemote = await txn.query(
            entityTable,
            where: 'remoteId = ?',
            whereArgs: [remoteId],
            limit: 1,
          );
          if (byRemote.isNotEmpty) {
            targetRow = byRemote.first;
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
          final byLocal = await txn.query(
            entityTable,
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          if (byLocal.isNotEmpty) targetRow = byLocal.first;
        }

        if (targetRow != null) {
          // -------- UPDATE path --------
          final localUpdatedAt = _parseLocalDate(targetRow['updatedAt']);
          final keepLocalBalances =
              localUpdatedAt != null && localUpdatedAt.isAfter(remoteSyncAt);

          final merged = Map<String, Object?>.from(baseData);
          if (keepLocalBalances) {
            merged.addAll({
              'balance': targetRow['balance'],
              'balanceDebt': targetRow['balanceDebt'],
              'isDirty': targetRow['isDirty'],
            });
          } else {
            merged.addAll(remoteBalances);
            merged['isDirty'] = 0;
          }

          // Only log if material fields will change
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
          // -------- INSERT path --------
          final createdAt = remoteSyncAt.toIso8601String();
          final idToUse =
              localId ??
              remoteId ??
              DateTime.now().microsecondsSinceEpoch.toString();

          await txn.insert(entityTable, {
            'id': idToUse,
            ...baseData,
            ...remoteBalances,
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
