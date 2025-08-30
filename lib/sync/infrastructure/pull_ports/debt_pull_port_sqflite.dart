// Sqflite pull port for debts with id adoption and conflict-aware upsert.
import 'package:sqflite/sqflite.dart';
import '../change_log_helper.dart';

typedef Json = Map<String, Object?>;

class DebtPullPortSqflite {
  final Database db;
  DebtPullPortSqflite(this.db);

  String get entityTable => 'debt';

  // ---------- helpers ----------
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

  bool _differs(Map<String, Object?> a, Map<String, Object?> b) {
    for (final k in a.keys) {
      if ('${a[k]}' != '${b[k]}') return true;
    }
    return false;
  }

  // ---------- Pass 1: adopt remote ids (never modify PK `id`) ----------
  Future<int> adoptRemoteIds(List<Json> items) async {
    if (items.isEmpty) return 0;
    int changed = 0;

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = _asStr(r['id']) ?? _asStr(r['remoteId']);
        final localId = _asStr(r['localId']);
        if (remoteId == null || localId == null) continue;

        // 1) row with PK == localId ?
        final localRows = await txn.query(
          entityTable,
          where: 'id = ?',
          whereArgs: [localId],
          limit: 1,
        );

        if (localRows.isNotEmpty) {
          final row = localRows.first;
          final curRemoteId = _asStr(row['remoteId']);
          final curLocalId = _asStr(row['localId']);

          // Already wired → SKIP (no changelog)
          if (curRemoteId == remoteId &&
              (curLocalId == null || curLocalId == localId)) {
            continue;
          }

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

          // Drop possible duplicate row with PK == remoteId (keep local PK)
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

        // 2) row with PK == remoteId ?
        final remoteRows = await txn.query(
          entityTable,
          where: 'id = ?',
          whereArgs: [remoteId],
          limit: 1,
        );
        if (remoteRows.isNotEmpty) {
          final row = remoteRows.first;
          final curRemoteId = _asStr(row['remoteId']);
          final curLocalId = _asStr(row['localId']);

          // Already wired → SKIP
          if (curRemoteId == remoteId && curLocalId == localId) {
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
        // else: insert will be handled in upsertRemote()
      }
    });

    return changed;
  }

  // ---------- Pass 2: upsert (no PK change on UPDATE; skip no-ops) ----------
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
        final notes = _asStr(r['notes']);
        final statuses = _asStr(r['statuses']);
        final customerId = _asStr(r['customerId']);
        final balance = _asInt(r['balance']);
        final balanceDebt = _asInt(r['balanceDebt']);
        final dueDate = _asStr(r['dueDate']);

        final remoteSyncAt = _asUtc(r['syncAt']);
        if (maxAt == null || remoteSyncAt.isAfter(maxAt!)) maxAt = remoteSyncAt;

        // Base fields (exclude 'id' so we never change PK on UPDATE)
        final base = <String, Object?>{
          'remoteId': remoteId,
          'localId': localId,
          'code': code,
          'notes': notes,
          'createdBy': _asStr(r['createdBy']) ?? "NA",
          'statuses': statuses,
          'customerId': customerId,
          'balance': balance,
          'balanceDebt': balanceDebt,
          'dueDate': dueDate,
          'syncAt': remoteSyncAt.toIso8601String(),
        };

        // Find target row
        Map<String, Object?>? target;
        if (remoteId != null) {
          final t1 = await txn.query(
            entityTable,
            where: 'remoteId = ?',
            whereArgs: [remoteId],
            limit: 1,
          );
          if (t1.isNotEmpty) target = t1.first;
          if (target == null) {
            final t2 = await txn.query(
              entityTable,
              where: 'id = ?',
              whereArgs: [remoteId],
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
        if (target == null && code != null) {
          final t4 = await txn.query(
            entityTable,
            where: 'code = ? AND deletedAt IS NULL',
            whereArgs: [code],
            limit: 1,
          );
          if (t4.isNotEmpty) target = t4.first;
        }

        if (target != null) {
          // UPDATE path
          final localUpdatedAt = _parseLocalDate(target['updatedAt']);
          final keepLocal =
              localUpdatedAt != null && localUpdatedAt.isAfter(remoteSyncAt);

          final merged = Map<String, Object?>.from(base);
          if (keepLocal) {
            // keep local balances / dirty bit
            merged['balance'] = target['balance'];
            merged['balanceDebt'] = target['balanceDebt'];
            merged['isDirty'] = target['isDirty'];
          } else {
            merged['isDirty'] = 0;
          }

          // Skip no-op updates
          final currentComparable = Map<String, Object?>.from(target)
            ..remove('id'); // ignore PK when comparing
          if (!_differs(merged, currentComparable)) {
            continue;
          }

          await txn.update(
            entityTable,
            merged,
            where: 'id = ?',
            whereArgs: [target['id']],
          );
          upserts++;
        } else {
          // INSERT path — safe PK set
          final newId =
              localId ??
              remoteId ??
              DateTime.now().microsecondsSinceEpoch.toString();
          final createdAt = remoteSyncAt.toIso8601String();
          await txn.insert(entityTable, {
            'id': newId,
            ...base,
            'createdAt': createdAt,
            'updatedAt': createdAt,
            'isDirty': 0,
          }, conflictAlgorithm: ConflictAlgorithm.abort);

          //force update for next
          if (_asStr(r['remoteId']) == null) {
            await upsertChangeLogPending(
              txn,
              entityTable: entityTable,
              entityId: newId ?? "-",
              operation: 'UPDATE',
            );
          }

          upserts++;
        }
      }
    });

    return (upserts: upserts, maxSyncAt: maxAt);
  }
}
