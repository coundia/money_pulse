// Sqflite pull port for transaction items with id adoption and conflict-aware upsert.
import 'package:sqflite/sqflite.dart';
import '../change_log_helper.dart';

typedef Json = Map<String, Object?>;

class TransactionItemPullPortSqflite {
  final Database db;
  TransactionItemPullPortSqflite(this.db);

  String get entityTable => 'transaction_item';

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

        // 1) Ligne locale par id == localId ?
        final localRows = await txn.query(
          entityTable,
          where: 'id = ?',
          whereArgs: [localId],
          limit: 1,
        );

        if (localRows.isNotEmpty) {
          final local = localRows.first;
          final alreadyRemote = _asStr(local['remoteId']);
          final alreadyLocal = _asStr(local['localId']);

          // --- Déjà câblé à ce remoteId → skip
          if (alreadyRemote == remoteId &&
              (alreadyLocal == null || alreadyLocal == localId) &&
              alreadyRemote != null) {
            continue;
          }

          // Sinon, on câble le lien (remoteId/localId) et on log
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

          // S'il existe un doublon dont la PK == remoteId, on le supprime
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

        // 2) Pas de ligne par localId → tenter la ligne dont la PK == remoteId
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

          // Si déjà identique → skip
          final needsUpdate = (curRemote != remoteId) || (curLocal != localId);
          if (!needsUpdate) continue;

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
        // 3) Sinon, rien à faire ici (l'upsert insérera plus tard)
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
        final transaction = _asStr(r['transaction']);
        final productId = _asStr(r['productId']);
        final label = _asStr(r['label']);
        final unitId = _asStr(r['unitId']);
        final notes = _asStr(r['notes']);
        final quantity = _asInt(r['quantity']);
        final unitPrice = _asInt(r['unitPrice']);
        final total = _asInt(r['total']);

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

        final base = <String, Object?>{
          'remoteId': remoteId,
          'localId': localId,
          'transactionId': transaction,
          'productId': productId,
          'label': label,
          'unitId': unitId,
          'notes': notes,
          'quantity': quantity,
          'unitPrice': unitPrice,
          'total': total,
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
            'id':
                remoteId ??
                localId ??
                DateTime.now().microsecondsSinceEpoch.toString(),
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
