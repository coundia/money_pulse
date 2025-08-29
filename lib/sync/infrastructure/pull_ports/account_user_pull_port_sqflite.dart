// Sqflite pull port for account_users with adoptRemoteIds + upsertRemote.
import 'package:sqflite/sqflite.dart';

import '../change_log_helper.dart';

typedef Json = Map<String, Object?>;

class AccountUserPullPortSqflite {
  final Database db;
  AccountUserPullPortSqflite(this.db);

  String get entityTable => 'account_users';

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
    final dt = DateTime.tryParse(
      s.contains('T') ? s : s.replaceFirst(' ', 'T'),
    );
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
        final account = _asStr(r['account']);
        final user = _asStr(r['user']);
        final email = _asStr(r['email']);
        final phone = _asStr(r['phone']);
        final role = _asStr(r['role']);
        final status = _asStr(r['status']);
        final invitedBy = _asStr(r['invitedBy']);
        final invitedAt = _asUtc(r['invitedAt']);
        final acceptedAt = _asUtc(r['acceptedAt']);
        final revokedAt = _asUtc(r['revokedAt']);
        final createdBy = _asStr(r['createdBy']);

        final remoteSyncAt = _asUtc(r['syncAt']);
        if (maxAt == null || remoteSyncAt.isAfter(maxAt!)) maxAt = remoteSyncAt;

        final base = <String, Object?>{
          'id':
              localId ??
              remoteId ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          'localId': localId ?? remoteId,
          'remoteId': remoteId,
          'account': account,
          'user': user,
          'email': email,
          'phone': phone,
          'role': role,
          'status': status,
          'invitedBy': invitedBy,
          'invitedAt': invitedAt.toIso8601String(),
          'acceptedAt': acceptedAt.toIso8601String(),
          'revokedAt': revokedAt.toIso8601String(),
          'createdBy': createdBy,
          'syncAt': remoteSyncAt.toIso8601String(),
        };

        Map<String, Object?>? target;
        if (remoteId != null) {
          final byRemote = await txn.query(
            entityTable,
            where: 'remoteId = ?',
            whereArgs: [remoteId],
            limit: 1,
          );
          if (byRemote.isNotEmpty) target = byRemote.first;
          if (target == null) {
            final byId = await txn.query(
              entityTable,
              where: 'id = ?',
              whereArgs: [remoteId],
              limit: 1,
            );
            if (byId.isNotEmpty) target = byId.first;
          }
        }
        if (target == null && localId != null) {
          final byLocal = await txn.query(
            entityTable,
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          if (byLocal.isNotEmpty) target = byLocal.first;
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
            'deletedAt': null,
            'version': _asInt(r['version']),
          }, conflictAlgorithm: ConflictAlgorithm.abort);
          upserts++;
        }

        if (_asStr(r['remoteId']) == null) {
          await upsertChangeLogPending(
            txn,
            entityTable: entityTable,
            entityId: localId ?? "-",
            operation: 'UPDATE',
          );
        }
      }
    });

    return (upserts: upserts, maxSyncAt: maxAt);
  }
}
