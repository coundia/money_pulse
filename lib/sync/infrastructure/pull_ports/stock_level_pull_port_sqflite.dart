// Sqflite pull port for stock levels with id adoption and conflict-aware upsert.
import 'package:sqflite/sqflite.dart';
import '../change_log_helper.dart';

typedef Json = Map<String, Object?>;

class StockLevelPullPortSqflite {
  final Database db;
  StockLevelPullPortSqflite(this.db);

  String get entityTable => 'stock_level';

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
          where: 'localId = ?',
          whereArgs: [localId],
          limit: 1,
        );
        if (localRows.isNotEmpty) {
          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId, 'isDirty': 1},
            where: 'localId = ?',
            whereArgs: [localId],
          );
          await upsertChangeLogPending(
            txn,
            entityTable: entityTable,
            entityId: localId,
            operation: 'UPDATE',
          );
          changed++;
          continue;
        }

        final byRemote = await txn.query(
          entityTable,
          where: 'remoteId = ?',
          whereArgs: [remoteId],
          limit: 1,
        );
        if (byRemote.isNotEmpty) {
          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId, 'isDirty': 1},
            where: 'remoteId = ?',
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
        final productVariantId = _asStr(r['productVariantId']);
        final companyId = _asStr(r['companyId']);
        final stockOnHand = _asInt(r['stockOnHand']);
        final stockAllocated = _asInt(r['stockAllocated']);

        final remoteSyncAt = _asUtc(r['syncAt']);
        if (maxAt == null || remoteSyncAt.isAfter(maxAt!)) maxAt = remoteSyncAt;

        final base = <String, Object?>{
          'remoteId': remoteId,
          'localId': localId,
          'productVariantId': productVariantId,
          'companyId': companyId,
          'stockOnHand': stockOnHand,
          'stockAllocated': stockAllocated,
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
        }
        if (target == null && localId != null) {
          final t2 = await txn.query(
            entityTable,
            where: 'localId = ?',
            whereArgs: [localId],
            limit: 1,
          );
          if (t2.isNotEmpty) target = t2.first;
        }
        if (target == null && productVariantId != null && companyId != null) {
          final t3 = await txn.query(
            entityTable,
            where:
                'productVariantId = ? AND companyId = ? AND deletedAt IS NULL',
            whereArgs: [productVariantId, companyId],
            limit: 1,
          );
          if (t3.isNotEmpty) target = t3.first;
        }

        if (target != null) {
          final localUpdatedAt = _parseLocalDate(target['updatedAt']);
          final keepLocal =
              localUpdatedAt != null && localUpdatedAt.isAfter(remoteSyncAt);
          final merged = Map<String, Object?>.from(base);
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
          final createdAt = remoteSyncAt.toIso8601String();
          await txn.insert(entityTable, {
            ...base,
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
