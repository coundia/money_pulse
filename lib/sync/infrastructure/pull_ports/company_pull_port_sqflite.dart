/* Sqflite pull port for companies: adopt remote ids using localId, then upsert fields, resolve conflicts, and log SYNCED rows in change_log. */
import 'package:sqflite/sqflite.dart';

typedef Json = Map<String, Object?>;

class CompanyPullPortSqflite {
  final Database db;
  CompanyPullPortSqflite(this.db);

  String get entityTable => 'company';

  String? _asStr(Object? v) => v?.toString();
  int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  DateTime _asUtc(Object? v) {
    if (v == null) return DateTime.now().toUtc();
    final dt = DateTime.tryParse(v.toString());
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
        final code = _asStr(r['code']);
        final name = _asStr(r['name']);
        final description = _asStr(r['description']);
        final phone = _asStr(r['phone']);
        final email = _asStr(r['email']);
        final website = _asStr(r['website']);
        final taxId = _asStr(r['taxId']);
        final currency = _asStr(r['currency']);
        final addressLine1 = _asStr(r['addressLine1']);
        final addressLine2 = _asStr(r['addressLine2']);
        final city = _asStr(r['city']);
        final region = _asStr(r['region']);
        final country = _asStr(r['country']);
        final postalCode = _asStr(r['postalCode']);
        final isDefault =
            r['isDefault'] == true ||
            r['isDefault'] == 1 ||
            r['isDefault'] == 'true';

        final remoteSyncAt = _asUtc(r['syncAt']);
        if (maxAt == null || remoteSyncAt.isAfter(maxAt!)) maxAt = remoteSyncAt;

        final baseData = <String, Object?>{
          'id': localId,
          'remoteId': remoteId,
          'localId': localId,
          'code': code,
          'name': name,
          'description': description,
          'phone': phone,
          'email': email,
          'website': website,
          'taxId': taxId,
          'currency': currency,
          'addressLine1': addressLine1,
          'addressLine2': addressLine2,
          'city': city,
          'region': region,
          'country': country,
          'postalCode': postalCode,
          'isDefault': isDefault ? 1 : 0,
          'syncAt': remoteSyncAt.toIso8601String(),
        };

        Map<String, Object?>? targetRow;
        if (remoteId != null) {
          final byRemoteId = await txn.query(
            entityTable,
            where: 'remoteId = ?',
            whereArgs: [remoteId],
            limit: 1,
          );
          if (byRemoteId.isNotEmpty) {
            targetRow = byRemoteId.first;
          } else {
            final byIdEqRemote = await txn.query(
              entityTable,
              where: 'id = ?',
              whereArgs: [remoteId],
              limit: 1,
            );
            if (byIdEqRemote.isNotEmpty) targetRow = byIdEqRemote.first;
          }
        }
        if (targetRow == null && localId != null) {
          final byLocalId = await txn.query(
            entityTable,
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          if (byLocalId.isNotEmpty) targetRow = byLocalId.first;
        }

        if (targetRow != null) {
          final localUpdatedAt = _parseLocalDate(targetRow['updatedAt']);
          final keepLocal =
              localUpdatedAt != null && localUpdatedAt.isAfter(remoteSyncAt);

          final merged = Map<String, Object?>.from(baseData);
          if (keepLocal) {
            merged['isDirty'] = targetRow['isDirty'];
          } else {
            merged['isDirty'] = 0;
          }

          await txn.update(
            entityTable,
            merged,
            where: 'id = ?',
            whereArgs: [targetRow['id']],
          );

          await txn.insert('change_log', {
            'id': '${targetRow['id']}-pull',
            'entityTable': entityTable,
            'entityId': targetRow['id'],
            'remoteId': remoteId,
            'localId': localId,
            'operation': 'UPDATE',
            'status': 'SYNCED',
            'payload': null,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          upserts++;
        } else {
          final createdAt = remoteSyncAt.toIso8601String();
          final id =
              remoteId ?? DateTime.now().microsecondsSinceEpoch.toString();

          await txn.insert(entityTable, {
            'id': id,
            ...baseData,
            'createdAt': createdAt,
            'updatedAt': createdAt,
            'isDirty': 0,
          }, conflictAlgorithm: ConflictAlgorithm.abort);

          await txn.insert('change_log', {
            'id': '$id-pull',
            'entityTable': entityTable,
            'entityId': id,
            'remoteId': remoteId,
            'localId': localId,
            'operation': 'INSERT',
            'status': 'SYNCED',
            'payload': null,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          upserts++;
        }
      }
    });

    return (upserts: upserts, maxSyncAt: maxAt);
  }
}
