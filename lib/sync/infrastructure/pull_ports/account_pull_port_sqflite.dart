// lib/sync/infrastructure/pull_ports/account_pull_port_sqflite.dart
//
// Sqflite pull port for accounts.
// Pass 1: adopt remote ids using `localId` (never change primary key `id`)
// Pass 2: upsert/merge fields. Before writing balances, compare remote.syncAt
//         vs local.updatedAt and keep the most recent balances.
//
// NOTE:
// - On UPDATE we never overwrite `updatedAt` (it's for local edits).
// - If local is newer for balances, we KEEP local balances and KEEP isDirty as-is.
// - If remote wins, we apply remote balances and set isDirty=0.
// - On INSERT we use remote balances, set isDirty=0, and set updatedAt=remote.syncAt.

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../change_log_helper.dart';

typedef Json = Map<String, Object?>;

class AccountPullPortSqflite {
  final Database db;
  AccountPullPortSqflite(this.db);

  String get entityTable => 'account';

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

  // ---------- Pass 1: adopt remote ids (never modify PK `id`) ----------

  /// Wire the server `id` (remoteId) to the local row referenced by `localId`.
  /// - If row exists with id==localId → set remoteId/localId on that row.
  ///   If a duplicate row exists with id==remoteId, delete the duplicate (keep local row).
  /// - Else if row exists with id==remoteId → set remoteId and store provided localId (mapping only).
  /// - Never update the primary key `id` here.
  Future<int> adoptRemoteIds(List<Json> items) async {
    if (items.isEmpty) return 0;
    int changed = 0;

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = _asStr(r['id']) ?? _asStr(r['remoteId']);
        final localId = _asStr(r['localId']);
        if (remoteId == null || localId == null) continue;

        // 1) Ligne locale (PK == localId) ?
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

          // Déjà câblé → SKIP (ne touche pas change_log)
          if (curRemoteId == remoteId &&
              (curLocalId == null || curLocalId == localId)) {
            continue;
          }

          // Câblage à faire
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

          // Supprimer un éventuel doublon (PK == remoteId) seulement si on a vraiment câblé
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

        // 2) Sinon, tenter la ligne dont la PK == remoteId
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

          // Déjà câblé → SKIP (ne touche pas change_log)
          if (curRemoteId == remoteId && curLocalId == localId) {
            continue;
          }

          // Câblage à faire
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
        // Sinon : insertion traitée plus tard par upsertRemote()
      }
    });

    return changed;
  }

  // ---------- Pass 2: upsert fields with balance conflict resolution ----------

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
        final name = _asStr(r['name']);
        final desc = _asStr(r['description']) ?? name;
        final currency = _asStr(r['currency']);
        final typeAccount = _asStr(r['typeAccount']);
        final isDefault =
            (r['isDefault'] == true) ||
            r['isDefault'] == 1 ||
            r['isDefault'] == 'true';
        final status = _asStr(r['status']);

        final remoteSyncAt = _asUtc(r['syncAt']);
        if (maxAt == null || remoteSyncAt.isAfter(maxAt!)) maxAt = remoteSyncAt;

        final baseData = <String, Object?>{
          'id': localId,
          'remoteId': remoteId,
          'localId': localId,
          'code': code,
          'description': desc,
          'currency': currency,
          'typeAccount': typeAccount,
          'isDefault': isDefault ? 1 : 0,
          'status': status,
          'syncAt': remoteSyncAt.toIso8601String(),
          // Do NOT set updatedAt on pull UPDATEs.
        };

        final remoteBalances = <String, Object?>{
          'balance': _asInt(r['balance']),
          'balance_prev': _asInt(r['balancePrev']),
          'balance_blocked': _asInt(r['balanceBlocked']),
          'balance_init': _asInt(r['balanceInit']),
          'balance_goal': _asInt(r['balanceGoal']),
          'balance_limit': _asInt(r['balanceLimit']),
        };

        // ---- Find the local target row (without changing PK) ----
        Map<String, Object?>? targetRow;
        if (remoteId != null) {
          final byRemoteId = await txn.query(
            'account',
            where: 'remoteId = ?',
            whereArgs: [remoteId],
            limit: 1,
          );
          if (byRemoteId.isNotEmpty) {
            targetRow = byRemoteId.first;
          } else {
            final byIdEqRemote = await txn.query(
              'account',
              where: 'id = ?',
              whereArgs: [remoteId],
              limit: 1,
            );
            if (byIdEqRemote.isNotEmpty) {
              targetRow = byIdEqRemote.first;
            }
          }
        }
        if (targetRow == null && localId != null) {
          final byLocalId = await txn.query(
            'account',
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          if (byLocalId.isNotEmpty) targetRow = byLocalId.first;
        }

        if (targetRow != null) {
          // -------- UPDATE path (do not touch updatedAt) --------
          final localUpdatedAt = _parseLocalDate(targetRow['updatedAt']);
          final keepLocalBalances =
              localUpdatedAt != null && localUpdatedAt.isAfter(remoteSyncAt);

          final merged = Map<String, Object?>.from(baseData);
          if (keepLocalBalances) {
            merged.addAll({
              'balance': targetRow['balance'],
              'balance_prev': targetRow['balance_prev'],
              'balance_blocked': targetRow['balance_blocked'],
              'balance_init': targetRow['balance_init'],
              'balance_goal': targetRow['balance_goal'],
              'balance_limit': targetRow['balance_limit'],
              'isDirty': targetRow['isDirty'], // keep existing dirty state
            });
          } else {
            merged.addAll(remoteBalances);
            merged['isDirty'] = 0; // remote wins → clean
          }

          await txn.update(
            'account',
            merged,
            where: 'id = ?',
            whereArgs: [targetRow['id']],
          );
          upserts++;
        } else {
          // -------- INSERT path (id is new; OK to set) --------
          // Use remoteSyncAt for updatedAt to avoid "local is newer" illusions.

          final createdAt = remoteSyncAt.toIso8601String();
          await txn.insert('account', {
            'id': localId ?? remoteId,
            ...baseData,
            ...remoteBalances,
            'createdAt': createdAt,
            'updatedAt': createdAt,
            'isDirty': 0,
          }, conflictAlgorithm: ConflictAlgorithm.abort);
          upserts++;
        }
      }
    });

    return (upserts: upserts, maxSyncAt: maxAt);
  }
}
