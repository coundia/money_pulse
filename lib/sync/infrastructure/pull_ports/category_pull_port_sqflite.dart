// Sqflite pull port for categories.
// Pass 1: adopt remote ids using localId (never change PK `id`)
// Pass 2: upsert/merge fields with updatedAt conflict resolution.

import 'package:sqflite/sqflite.dart';

typedef Json = Map<String, Object?>;

class CategoryPullPortSqflite {
  final Database db;
  CategoryPullPortSqflite(this.db);

  String get entityTable => 'category';

  String? _asStr(Object? v) => v?.toString();
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

  Future<int> adoptRemoteIds(List<Json> items) async {
    if (items.isEmpty) return 0;
    int changed = 0;
    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = _asStr(r['id']) ?? _asStr(r['remoteId']);
        final localId = _asStr(r['localId']);
        if (remoteId == null || localId == null) continue;

        final localRows = await txn.query(
          'category',
          where: 'id = ?',
          whereArgs: [localId],
          limit: 1,
        );
        if (localRows.isNotEmpty) {
          await txn.update(
            'category',
            {'remoteId': remoteId, 'localId': localId},
            where: 'id = ?',
            whereArgs: [localId],
          );
          if (remoteId != localId) {
            final dup = await txn.query(
              'category',
              where: 'id = ?',
              whereArgs: [remoteId],
              limit: 1,
            );
            if (dup.isNotEmpty) {
              await txn.delete(
                'category',
                where: 'id = ?',
                whereArgs: [remoteId],
              );
            }
          }
          changed++;
          continue;
        }

        final remoteRows = await txn.query(
          'category',
          where: 'id = ?',
          whereArgs: [remoteId],
          limit: 1,
        );
        if (remoteRows.isNotEmpty) {
          await txn.update(
            'category',
            {'remoteId': remoteId, 'localId': localId},
            where: 'id = ?',
            whereArgs: [remoteId],
          );
          changed++;
        }
      }
    });
    return changed;
  }

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
        final desc = _asStr(r['description']);
        final typeEntry = _asStr(r['typeEntry']) ?? 'DEBIT';

        final remoteSyncAt = _asUtc(r['syncAt']);
        if (maxAt == null || remoteSyncAt.isAfter(maxAt!)) maxAt = remoteSyncAt;

        final baseData = <String, Object?>{
          'remoteId': remoteId,
          'localId': localId,
          'code': code,
          'description': desc,
          'typeEntry': typeEntry,
          'syncAt': remoteSyncAt.toIso8601String(),
        };

        Map<String, Object?>? targetRow;
        if (remoteId != null) {
          final byRemoteId = await txn.query(
            'category',
            where: 'remoteId = ?',
            whereArgs: [remoteId],
            limit: 1,
          );
          if (byRemoteId.isNotEmpty) targetRow = byRemoteId.first;
        }
        if (targetRow == null && localId != null) {
          final byLocalId = await txn.query(
            'category',
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          if (byLocalId.isNotEmpty) targetRow = byLocalId.first;
        }
        if (targetRow == null && code != null) {
          final byCode = await txn.query(
            'category',
            where: 'code = ? AND deletedAt IS NULL',
            whereArgs: [code],
            limit: 1,
          );
          if (byCode.isNotEmpty) targetRow = byCode.first;
        }

        if (targetRow != null) {
          await txn.update(
            'category',
            baseData,
            where: 'id = ?',
            whereArgs: [targetRow['id']],
          );
          upserts++;
        } else {
          final createdAt = remoteSyncAt.toIso8601String();
          await txn.insert('category', {
            'id': remoteId ?? DateTime.now().microsecondsSinceEpoch.toString(),
            ...baseData,
            'createdAt': createdAt,
            'updatedAt': createdAt,
            'isDirty': 0,
          });
          upserts++;
        }
      }
    });
    return (upserts: upserts, maxSyncAt: maxAt);
  }
}
