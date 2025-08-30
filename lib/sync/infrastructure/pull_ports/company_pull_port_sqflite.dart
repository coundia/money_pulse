// lib/sync/infrastructure/pull_ports/company_pull_port_sqflite.dart
//
// Sqflite pull port for companies:
// - Pass 1: adopt remote ids using localId (never change PK `id`, no change_log)
// - Pass 2: upsert/merge fields with conflict resolution (local.updatedAt vs remote.syncAt)
// - UPDATE: log to change_log via upsertChangeLogPending **only if material fields changed**
// - INSERT: no change_log (source = remote); set updatedAt = remote.syncAt

import 'package:sqflite/sqflite.dart';
import '../change_log_helper.dart';

typedef Json = Map<String, Object?>;

class CompanyPullPortSqflite {
  final Database db;
  CompanyPullPortSqflite(this.db);

  String get entityTable => 'company';

  String? _asStr(Object? v) => v?.toString();

  int _asInt(Object? v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
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

  bool _differs(
    Map<String, Object?> a,
    Map<String, Object?> b,
    Iterable<String> keys,
  ) {
    for (final k in keys) {
      final va = a[k];
      final vb = b[k];
      if (va is String && vb is String) {
        if (va != vb) return true;
      } else {
        // normaliser bool/ints pour isDefault
        if (k == 'isDefault') {
          final ai = (va is bool) ? (va ? 1 : 0) : _asInt(va, fallback: 0);
          final bi = (vb is bool) ? (vb ? 1 : 0) : _asInt(vb, fallback: 0);
          if (ai != bi) return true;
        } else if ((va ?? '') != (vb ?? '')) {
          return true;
        }
      }
    }
    return false;
  }

  static const _materialKeys = <String>{
    'remoteId',
    'localId',
    'code',
    'name',
    'description',
    'phone',
    'email',
    'website',
    'taxId',
    'currency',
    'addressLine1',
    'addressLine2',
    'city',
    'region',
    'country',
    'postalCode',
    'isDefault',
  };

  // -------- Pass 1: adopt remote ids (no change_log here) --------
  Future<int> adoptRemoteIds(List<Json> items) async {
    if (items.isEmpty) return 0;
    int changed = 0;

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = _asStr(r['id']) ?? _asStr(r['remoteId']);
        final localId = _asStr(r['localId']);
        if (remoteId == null || localId == null) continue;

        // 1) Ligne locale (PK == localId) ?
        final localRows = await txn.query(
          entityTable,
          where: 'id = ?',
          whereArgs: [localId],
          limit: 1,
        );
        if (localRows.isNotEmpty) {
          final row = localRows.first;
          final curRemote = _asStr(row['remoteId']);
          final curLocal = _asStr(row['localId']);

          // déjà câblé → skip
          if (curRemote == remoteId &&
              (curLocal == null || curLocal == localId)) {
            continue;
          }

          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId},
            where: 'id = ?',
            whereArgs: [localId],
          );

          await upsertChangeLogPending(
            txn,
            entityTable: entityTable,
            entityId: localId,
            operation: 'UPDATE',
          );

          // supprimer doublon éventuel (PK == remoteId)
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

        // 2) Pas de localId → tenter PK == remoteId
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

          if (curRemote == remoteId && curLocal == localId) {
            continue;
          }

          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId},
            where: 'id = ?',
            whereArgs: [remoteId],
          );
          changed++;
        }
        // sinon: insert géré par upsertRemote
      }
    });

    return changed;
  }

  // -------- Pass 2: upsert + log UPDATEs that actually changed material fields --------
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
        final address1 = _asStr(r['addressLine1']);
        final address2 = _asStr(r['addressLine2']);
        final city = _asStr(r['city']);
        final region = _asStr(r['region']);
        final country = _asStr(r['country']);
        final postalCode = _asStr(r['postalCode']);
        final isDefault =
            (r['isDefault'] == true) ||
            r['isDefault'] == 1 ||
            r['isDefault'] == 'true';

        final remoteSyncAt = _asUtc(r['syncAt']);
        if (maxAt == null || remoteSyncAt.isAfter(maxAt!)) maxAt = remoteSyncAt;

        // base pour UPDATE (sans 'id')
        final baseData = <String, Object?>{
          'remoteId': remoteId,
          'localId': localId,
          'code': code,
          'name': name,
          'createdBy': _asStr(r['createdBy']) ?? "NA",
          'description': description,
          'phone': phone,
          'email': email,
          'website': website,
          'taxId': taxId,
          'currency': currency,
          'addressLine1': address1,
          'addressLine2': address2,
          'city': city,
          'region': region,
          'country': country,
          'postalCode': postalCode,
          'isDefault': isDefault ? 1 : 0,
          'syncAt': remoteSyncAt.toIso8601String(),
        };

        // Trouver la cible (ne jamais changer la PK)
        Map<String, Object?>? targetRow;
        if (remoteId != null) {
          final byRemote = await txn.query(
            entityTable,
            where: 'remoteId = ?',
            whereArgs: [remoteId],
            limit: 1,
          );
          if (byRemote.isNotEmpty) targetRow = byRemote.first;
          if (targetRow == null) {
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
          final byLocal = await txn.query(
            entityTable,
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          if (byLocal.isNotEmpty) targetRow = byLocal.first;
        }

        if (targetRow != null) {
          // UPDATE path
          final localUpdatedAt = _parseLocalDate(targetRow['updatedAt']);
          final keepLocal =
              localUpdatedAt != null && localUpdatedAt.isAfter(remoteSyncAt);

          final merged = Map<String, Object?>.from(baseData);
          if (keepLocal) {
            // garder valeurs locales, juste syncAt rafraîchi
            for (final k in _materialKeys) {
              if (k == 'isDefault') {
                merged[k] = _asInt(targetRow[k], fallback: 0);
              } else {
                merged[k] = targetRow[k];
              }
            }
            merged['isDirty'] = targetRow['isDirty'];
          } else {
            // remote gagne
            merged['isDirty'] = 0;
          }

          // log uniquement si des champs matériels changent (ignorer syncAt/isDirty)
          final currentComparable = {
            for (final k in _materialKeys) k: targetRow[k],
          };
          final mergedComparable = {
            for (final k in _materialKeys) k: merged[k],
          };
          final willLog = _differs(
            currentComparable,
            mergedComparable,
            _materialKeys,
          );

          await txn.update(
            entityTable,
            merged,
            where: 'id = ?',
            whereArgs: [targetRow['id']],
          );

          if (willLog) {
            await upsertChangeLogPending(
              txn,
              entityTable: entityTable,
              entityId: (targetRow['id'] ?? localId ?? remoteId).toString(),
              operation: 'UPDATE',
            );
          }

          upserts++;
        } else {
          // INSERT path — source remote; pas de change_log
          final createdAt = remoteSyncAt.toIso8601String();
          final idToUse =
              localId ??
              remoteId ??
              DateTime.now().microsecondsSinceEpoch.toString();

          await txn.insert(entityTable, {
            'id': idToUse,
            ...baseData,
            'createdAt': createdAt,
            'updatedAt': createdAt,
            'isDirty': 0,
          }, conflictAlgorithm: ConflictAlgorithm.abort);
          upserts++;

          //force update for next
          if (_asStr(r['remoteId']) == null) {
            await upsertChangeLogPending(
              txn,
              entityTable: entityTable,
              entityId: idToUse ?? "-",
              operation: 'UPDATE',
            );
          }
        }
      }
    });

    return (upserts: upserts, maxSyncAt: maxAt);
  }
}
