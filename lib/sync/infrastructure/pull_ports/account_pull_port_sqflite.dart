// lib/sync/infrastructure/pull_ports/account_pull_port_sqflite.dart
//
// Sqflite pull port for accounts.
// Pass 1: adopt remote ids using `localId`
// Pass 2: upsert/merge fields and clear isDirty.
// IMPORTANT: if a local row exists with id == localId, we UPDATE it (no insert).

import 'package:sqflite/sqflite.dart';

typedef Json = Map<String, Object?>;

class AccountPullPortSqflite {
  final Database db;
  AccountPullPortSqflite(this.db);

  String get entityTable => 'account';

  // ---------- Helpers ----------

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

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

  // ---------- Pass 1: adopt remote ids ----------

  /// Bind remote `id` to the local row pointed by `localId`.
  /// - If row exists with id==localId:
  ///   - set remoteId/localId fields
  ///   - if remoteId != localId:
  ///       * if a row exists with id==remoteId → merge then delete local
  ///       * else rename PK (id: localId -> remoteId)
  /// - If only a row exists with id==remoteId → set remoteId/localId there.
  Future<int> adoptRemoteIds(List<Json> items) async {
    if (items.isEmpty) return 0;
    int changed = 0;
    final nowIso = _nowIso();

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = _asStr(r['id']) ?? _asStr(r['remoteId']);
        final localId = _asStr(r['localId']);
        if (remoteId == null || localId == null) continue;

        final localRows = await txn.query(
          'account',
          where: 'id = ?',
          whereArgs: [localId],
          limit: 1,
        );

        if (localRows.isEmpty) {
          final remoteRows = await txn.query(
            'account',
            where: 'id = ?',
            whereArgs: [remoteId],
            limit: 1,
          );
          if (remoteRows.isNotEmpty) {
            await txn.update(
              'account',
              {
                'remoteId': remoteId,
                'localId': localId,
                'updatedAt': nowIso,
                'isDirty': 0,
              },
              where: 'id = ?',
              whereArgs: [remoteId],
            );
            changed++;
          }
          continue;
        }

        if (remoteId == localId) {
          await txn.update(
            'account',
            {
              'remoteId': remoteId,
              'localId': localId,
              'updatedAt': nowIso,
              'isDirty': 0,
            },
            where: 'id = ?',
            whereArgs: [localId],
          );
          changed++;
          continue;
        }

        final targetRows = await txn.query(
          'account',
          where: 'id = ?',
          whereArgs: [remoteId],
          limit: 1,
        );

        if (targetRows.isNotEmpty) {
          await txn.update(
            'account',
            {
              'remoteId': remoteId,
              'localId': localId,
              'updatedAt': nowIso,
              'isDirty': 0,
            },
            where: 'id = ?',
            whereArgs: [remoteId],
          );
          await txn.delete('account', where: 'id = ?', whereArgs: [localId]);
        } else {
          await txn.update(
            'account',
            {'id': remoteId},
            where: 'id = ?',
            whereArgs: [localId],
          );
          await txn.update(
            'account',
            {
              'remoteId': remoteId,
              'localId': localId,
              'updatedAt': nowIso,
              'isDirty': 0,
            },
            where: 'id = ?',
            whereArgs: [remoteId],
          );
        }
        changed++;
      }
    });

    return changed;
  }

  // ---------- Pass 2: upsert fields ----------

  /// Upsert remote fields (balances, flags, etc.). De-duplicates by:
  /// - remoteId (preferred),
  /// - id==remoteId (when remoteId not set),
  /// - **id==localId (new: update local row, never insert)**,
  /// - active `code` as an additional fallback,
  /// - insert only if none of the above matched.
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

        final syncAt = _asUtc(r['syncAt']);
        if (maxAt == null || syncAt.isAfter(maxAt!)) maxAt = syncAt;

        final nowIso = _nowIso();
        final data = <String, Object?>{
          'remoteId': remoteId,
          'localId': localId,
          'code': code,
          'description': desc,
          'currency': currency,
          'typeAccount': typeAccount,
          'isDefault': isDefault ? 1 : 0,
          'status': status,
          'syncAt': syncAt.toIso8601String(),
          'updatedAt': nowIso,
          'isDirty': 0,
          'balance': _asInt(r['balance']),
          'balance_prev': _asInt(r['balancePrev']),
          'balance_blocked': _asInt(r['balanceBlocked']),
          'balance_init': _asInt(r['balanceInit']),
          'balance_goal': _asInt(r['balanceGoal']),
          'balance_limit': _asInt(r['balanceLimit']),
        };

        bool changed = false;

        // 1) Update by remoteId (preferred)
        if (remoteId != null) {
          final u1 = await txn.update(
            'account',
            data,
            where: 'remoteId = ?',
            whereArgs: [remoteId],
          );
          if (u1 > 0) {
            upserts++;
            changed = true;
          } else {
            // Or by id==remoteId (while remoteId column not set yet)
            final u2 = await txn.update(
              'account',
              data,
              where: 'id = ?',
              whereArgs: [remoteId],
            );
            if (u2 > 0) {
              upserts++;
              changed = true;
            }
          }
        }

        // 2) NEW: Update by localId → means it exists locally; do NOT insert.
        if (!changed && localId != null) {
          final u = await txn.update(
            'account',
            data,
            where: 'id = ?',
            whereArgs: [localId],
          );
          if (u > 0) {
            upserts++;
            changed = true;
          }
        }

        // 3) Fallback: update by active code
        if (!changed && code != null) {
          final u = await txn.update(
            'account',
            data,
            where: 'code = ? AND deletedAt IS NULL',
            whereArgs: [code],
          );
          if (u > 0) {
            upserts++;
            changed = true;
          }
        }

        // 4) Insert only if nothing matched above
        if (!changed) {
          try {
            await txn.insert('account', {
              'id':
                  remoteId ?? DateTime.now().microsecondsSinceEpoch.toString(),
              ...data,
              'createdAt': nowIso,
            }, conflictAlgorithm: ConflictAlgorithm.abort);
            upserts++;
            changed = true;
          } on DatabaseException catch (e) {
            // Merge by code if UNIQUE(code) exists elsewhere in your schema
            final isUnique = e.toString().contains('UNIQUE constraint failed');
            if (isUnique && code != null) {
              final u = await txn.update(
                'account',
                data,
                where: 'code = ? AND deletedAt IS NULL',
                whereArgs: [code],
              );
              if (u > 0) {
                upserts++;
                changed = true;
              } else {
                rethrow;
              }
            } else {
              rethrow;
            }
          }
        }
      }
    });

    return (upserts: upserts, maxSyncAt: maxAt);
  }
}
