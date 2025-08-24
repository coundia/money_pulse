import 'package:sqflite/sqflite.dart';

typedef Json = Map<String, Object?>;

class AccountPullPortSqflite {
  final Database db;
  AccountPullPortSqflite(this.db);

  String get entityTable => 'account';

  /// Upsert items from server; if server sends `localId`, adopt remote id as PK
  /// and repoint children (transaction_entry.accountId).
  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(
    List<Json> items,
  ) async {
    if (items.isEmpty) return (upserts: 0, maxSyncAt: null);

    int upserts = 0;
    DateTime? maxAt;

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = (r['id'] ?? r['remoteId'])?.toString();
        if (remoteId == null || remoteId.isEmpty) continue;

        final localId = r['localId']?.toString();
        final code = r['code']?.toString();
        final desc = (r['description'] ?? r['name'])?.toString();
        final currency = r['currency']?.toString();
        final typeAccount = r['typeAccount']?.toString();
        final isDefault = (r['isDefault'] == true) || r['isDefault'] == 1;
        final status = r['status']?.toString();

        final syncAtStr = r['syncAt']?.toString();
        final syncAt = syncAtStr == null
            ? DateTime.now().toUtc()
            : (DateTime.tryParse(syncAtStr)?.toUtc() ?? DateTime.now().toUtc());
        if (maxAt == null || syncAt.isAfter(maxAt!)) maxAt = syncAt;

        final nowIso = DateTime.now().toUtc().toIso8601String();
        final data = <String, Object?>{
          'remoteId': remoteId,
          'code': code,
          'description': desc,
          'currency': currency,
          'typeAccount': typeAccount,
          'isDefault': isDefault ? 1 : 0,
          'status': status,
          'syncAt': syncAt.toIso8601String(),
          'updatedAt': nowIso,
          'isDirty': 0,
        };

        bool handled = false;

        // Adopt: move local PK => remoteId
        if (localId != null && localId.isNotEmpty) {
          final localRow = await txn.query(
            'account',
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          if (localRow.isNotEmpty) {
            final remoteRow = await txn.query(
              'account',
              where: 'id = ?',
              whereArgs: [remoteId],
              limit: 1,
            );
            if (remoteRow.isEmpty) {
              // create remote shell, redirect children, drop local, finalize
              try {
                await txn.insert('account', {
                  'id': remoteId,
                  'localId': localId,
                  ...data,
                  'createdAt': nowIso,
                  'balance': (r['balance'] as num?)?.toInt() ?? 0,
                  'balance_prev': (r['balancePrev'] as num?)?.toInt() ?? 0,
                  'balance_blocked':
                      (r['balanceBlocked'] as num?)?.toInt() ?? 0,
                  'balance_init': (r['balanceInit'] as num?)?.toInt() ?? 0,
                  'balance_goal': (r['balanceGoal'] as num?)?.toInt() ?? 0,
                  'balance_limit': (r['balanceLimit'] as num?)?.toInt() ?? 0,
                }, conflictAlgorithm: ConflictAlgorithm.abort);
              } catch (_) {}

              await txn.update(
                'transaction_entry',
                {'accountId': remoteId},
                where: 'accountId = ?',
                whereArgs: [localId],
              );

              await txn.delete(
                'account',
                where: 'id = ?',
                whereArgs: [localId],
              );
              await txn.update(
                'account',
                data,
                where: 'id = ?',
                whereArgs: [remoteId],
              );
              upserts++;
              handled = true;
            } else {
              // already have remote row; just update/redirect and remove local
              await txn.update(
                'account',
                data,
                where: 'id = ?',
                whereArgs: [remoteId],
              );
              await txn.update(
                'transaction_entry',
                {'accountId': remoteId},
                where: 'accountId = ?',
                whereArgs: [localId],
              );
              await txn.delete(
                'account',
                where: 'id = ?',
                whereArgs: [localId],
              );
              upserts++;
              handled = true;
            }
          }
        }
        if (handled) continue;

        // Update by remoteId or by id==remoteId (already adopted locally)
        final uByRemote = await txn.update(
          'account',
          data,
          where: 'remoteId = ? OR id = ?',
          whereArgs: [remoteId, remoteId],
        );
        if (uByRemote > 0) {
          upserts++;
          continue;
        }

        // Update by active code
        if (code != null) {
          final uByCode = await txn.update(
            'account',
            data,
            where: 'code = ? AND deletedAt IS NULL',
            whereArgs: [code],
          );
          if (uByCode > 0) {
            upserts++;
            continue;
          }
        }

        // Insert fresh
        try {
          await txn.insert('account', {
            'id': remoteId,
            ...data,
            'createdAt': nowIso,
            'balance': (r['balance'] as num?)?.toInt() ?? 0,
            'balance_prev': (r['balancePrev'] as num?)?.toInt() ?? 0,
            'balance_blocked': (r['balanceBlocked'] as num?)?.toInt() ?? 0,
            'balance_init': (r['balanceInit'] as num?)?.toInt() ?? 0,
            'balance_goal': (r['balanceGoal'] as num?)?.toInt() ?? 0,
            'balance_limit': (r['balanceLimit'] as num?)?.toInt() ?? 0,
          }, conflictAlgorithm: ConflictAlgorithm.abort);
          upserts++;
        } catch (_) {
          await txn.update(
            'account',
            data,
            where: 'id = ?',
            whereArgs: [remoteId],
          );
          upserts++;
        }
      }
    });

    return (upserts: upserts, maxSyncAt: maxAt);
  }
}
