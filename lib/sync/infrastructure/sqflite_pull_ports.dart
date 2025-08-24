/* Sqflite pull port for accounts: match by remoteId, then active code, else insert. */
import 'package:sqflite/sqflite.dart';

typedef Json = Map<String, Object?>;

class AccountPullPortSqflite {
  final Database db;
  AccountPullPortSqflite(this.db);

  String get entityTable => 'account';

  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(
    List<Json> items,
  ) async {
    if (items.isEmpty) return (upserts: 0, maxSyncAt: null);
    final b = db.batch();
    DateTime? maxAt;

    for (final r in items) {
      final remoteId = (r['id'] ?? r['remoteId'])?.toString();
      final code = r['code']?.toString();
      final name = r['name']?.toString();
      final desc = (r['description'] ?? name)?.toString();
      final currency = r['currency']?.toString();
      final typeAccount = r['typeAccount']?.toString();
      final isDefault = (r['isDefault'] == true) || r['isDefault'] == 1;
      final status = r['status']?.toString();

      final syncAtStr = r['syncAt']?.toString();
      final syncAt = syncAtStr == null
          ? DateTime.now()
          : DateTime.tryParse(syncAtStr) ?? DateTime.now();
      if (maxAt == null || syncAt.isAfter(maxAt)) maxAt = syncAt;

      final data = <String, Object?>{
        'remoteId': remoteId,
        'code': code,
        'description': desc,
        'currency': currency,
        'typeAccount': typeAccount,
        'isDefault': isDefault ? 1 : 0,
        'status': status,
        'syncAt': syncAt.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isDirty': 0,
      };

      if (remoteId != null) {
        b.update('account', data, where: 'remoteId = ?', whereArgs: [remoteId]);
      }
      if (code != null) {
        b.update(
          'account',
          data,
          where: 'code = ? AND deletedAt IS NULL',
          whereArgs: [code],
        );
      }
      b.insert('account', {
        'id':
            remoteId ??
            code ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        ...data,
        'createdAt': DateTime.now().toIso8601String(),
        'balance': (r['balance'] as num?)?.toInt() ?? 0,
        'balance_prev': (r['balancePrev'] as num?)?.toInt() ?? 0,
        'balance_blocked': (r['balanceBlocked'] as num?)?.toInt() ?? 0,
        'balance_init': (r['balanceInit'] as num?)?.toInt() ?? 0,
        'balance_goal': (r['balanceGoal'] as num?)?.toInt() ?? 0,
        'balance_limit': (r['balanceLimit'] as num?)?.toInt() ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await b.commit(noResult: true);
    return (upserts: items.length, maxSyncAt: maxAt);
  }
}
