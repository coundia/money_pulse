/* Sqflite pull port for categories with de-duplication and legacy merge:
 * - Update by remoteId first,
 * - else update by active code,
 * - else if a local row exists with id == remoteId, update that row,
 * - else insert.
 */
import 'package:sqflite/sqflite.dart';

typedef Json = Map<String, Object?>;

class CategoryPullPortSqflite {
  final Database db;
  CategoryPullPortSqflite(this.db);

  String get entityTable => 'category';

  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(
    List<Json> items,
  ) async {
    if (items.isEmpty) return (upserts: 0, maxSyncAt: null);

    int upserts = 0;
    DateTime? maxAt;

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = (r['id'] ?? r['remoteId'])?.toString();
        final code = r['code']?.toString();
        final desc = (r['description'] ?? r['name'])?.toString();
        final rawType = (r['typeEntry'] ?? 'DEBIT').toString().toUpperCase();
        final typeEntry = (rawType == 'CREDIT') ? 'CREDIT' : 'DEBIT';

        final syncAtStr = r['syncAt']?.toString();
        final syncAt = syncAtStr == null
            ? DateTime.now().toUtc()
            : (DateTime.tryParse(syncAtStr)?.toUtc() ?? DateTime.now().toUtc());
        if (maxAt == null || syncAt.isAfter(maxAt!)) maxAt = syncAt;

        final nowIso = DateTime.now().toUtc().toIso8601String();
        final patch = <String, Object?>{
          'remoteId': remoteId,
          'code': code,
          'description': desc,
          'typeEntry': typeEntry,
          'syncAt': syncAt.toIso8601String(),
          'updatedAt': nowIso,
          'isDirty': 0,
        };

        bool changed = false;

        if (remoteId != null) {
          final u = await txn.update(
            'category',
            patch,
            where: 'remoteId = ?',
            whereArgs: [remoteId],
          );
          if (u > 0) {
            upserts++;
            changed = true;
          }
        }

        if (!changed && code != null) {
          final u = await txn.update(
            'category',
            patch,
            where: 'code = ? AND deletedAt IS NULL',
            whereArgs: [code],
          );
          if (u > 0) {
            upserts++;
            changed = true;
          }
        }

        if (!changed && remoteId != null) {
          final rows = await txn.query(
            'category',
            columns: const ['id'],
            where: 'id = ?',
            whereArgs: [remoteId],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            final u = await txn.update(
              'category',
              patch,
              where: 'id = ?',
              whereArgs: [remoteId],
            );
            if (u > 0) {
              upserts++;
              changed = true;
            }
          }
        }

        if (!changed) {
          try {
            await txn.insert('category', {
              'id':
                  remoteId ?? DateTime.now().microsecondsSinceEpoch.toString(),
              ...patch,
              'createdAt': nowIso,
              'version': (r['version'] as num?)?.toInt() ?? 0,
            }, conflictAlgorithm: ConflictAlgorithm.abort);
            upserts++;
            changed = true;
          } on DatabaseException catch (e) {
            final msg = e.toString();
            final isUnique = msg.contains('UNIQUE constraint failed');

            if (isUnique) {
              if (code != null) {
                final u = await txn.update(
                  'category',
                  patch,
                  where: 'code = ? AND deletedAt IS NULL',
                  whereArgs: [code],
                );
                if (u > 0) {
                  upserts++;
                  changed = true;
                }
              }
              if (!changed && remoteId != null) {
                final u = await txn.update(
                  'category',
                  patch,
                  where: 'remoteId = ?',
                  whereArgs: [remoteId],
                );
                if (u > 0) {
                  upserts++;
                  changed = true;
                }
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
