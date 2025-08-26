// Sqflite pull port for products with id adoption and conflict-aware upsert.
import 'package:sqflite/sqflite.dart';
import '../change_log_helper.dart';

typedef Json = Map<String, Object?>;

class ProductPullPortSqflite {
  final Database db;
  ProductPullPortSqflite(this.db);

  String get entityTable => 'product';

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

  Future<int> adoptRemoteIds(List<Json> items) async {
    if (items.isEmpty) return 0;
    int changed = 0;

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = _asStr(r['id']) ?? _asStr(r['remoteId']);
        final localId = _asStr(r['localId']);
        if (remoteId == null || localId == null) continue;

        final localRows = await txn.query(
          entityTable,
          where: 'id = ?',
          whereArgs: [localId],
          limit: 1,
        );
        if (localRows.isNotEmpty) {
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
          final dup = await txn.query(
            entityTable,
            where: 'id = ?',
            whereArgs: [remoteId],
            limit: 1,
          );
          if (dup.isNotEmpty && remoteId != localId) {
            await txn.delete(
              entityTable,
              where: 'id = ?',
              whereArgs: [remoteId],
            );
          }
          changed++;
          continue;
        }

        final remoteRows = await txn.query(
          entityTable,
          where: 'id = ?',
          whereArgs: [remoteId],
          limit: 1,
        );
        if (remoteRows.isNotEmpty) {
          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId, 'isDirty': 1},
            where: 'id = ?',
            whereArgs: [remoteId],
          );
          await upsertChangeLogPending(
            txn,
            entityTable: entityTable,
            entityId: localId,
            operation: 'UPDATE',
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
        final name = _asStr(r['name']);
        final desc = _asStr(r['description']) ?? name;
        final barcode = _asStr(r['barcode']);
        final unitId = _asStr(r['unitId']);
        final categoryId = _asStr(r['categoryId']);
        final statuses = _asStr(r['statuses']);
        final defaultPrice = _asInt(r['defaultPrice']);
        final purchasePrice = _asInt(r['purchasePrice']);

        final remoteSyncAt = _asUtc(r['syncAt']);
        if (maxAt == null || remoteSyncAt.isAfter(maxAt!)) maxAt = remoteSyncAt;

        final base = <String, Object?>{
          'id': localId,
          'remoteId': remoteId,
          'localId': localId,
          'code': code,
          'name': name,
          'description': desc,
          'barcode': barcode,
          'unitId': unitId,
          'categoryId': categoryId,
          'statuses': statuses,
          'syncAt': remoteSyncAt.toIso8601String(),
        };

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
          final localUpdatedAt = _parseLocalDate(target['updatedAt']);
          final keepLocal =
              localUpdatedAt != null && localUpdatedAt.isAfter(remoteSyncAt);
          final merged = Map<String, Object?>.from(base);
          if (keepLocal) {
            merged.addAll({
              'defaultPrice': target['defaultPrice'],
              'purchasePrice': target['purchasePrice'],
              'isDirty': target['isDirty'],
            });
          } else {
            merged.addAll({
              'defaultPrice': defaultPrice,
              'purchasePrice': purchasePrice,
              'isDirty': 0,
            });
          }
          await txn.update(
            entityTable,
            merged,
            where: 'id = ?',
            whereArgs: [target['id']],
          );

          upserts++;
        } else {
          final createdAt = remoteSyncAt.toIso8601String();
          await txn.insert(entityTable, {
            'id':
                remoteId ??
                localId ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            ...base,
            'defaultPrice': defaultPrice,
            'purchasePrice': purchasePrice,
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
