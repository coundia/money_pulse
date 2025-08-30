// lib/sync/infrastructure/pull_ports/category_pull_port_sqflite.dart
//
// Sqflite pull port for categories.
// Pass 1: adopt remote ids using localId (never change PK `id`)
// Pass 2: upsert/merge fields with updatedAt vs syncAt conflict resolution.
// - No change_log writes in adopt pass.
// - Log to change_log on UPDATE only if material fields really changed
//   (ignoring syncAt-only updates).

import 'package:sqflite/sqflite.dart';
import '../change_log_helper.dart';

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
      } else if ((va ?? '') != (vb ?? '')) {
        return true;
      }
    }
    return false;
  }

  // Champs considérés comme “matériels” pour décider de logguer un UPDATE.
  static const _materialKeys = <String>{
    'remoteId',
    'localId',
    'code',
    'description',
    'typeEntry',
  };

  // ---------------- Pass 1: adopt remote ids (no change_log) ----------------

  Future<int> adoptRemoteIds(List<Json> items) async {
    if (items.isEmpty) return 0;
    int changed = 0;

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = _asStr(r['id']) ?? _asStr(r['remoteId']);
        final localId = _asStr(r['localId']);
        if (remoteId == null || localId == null) continue;

        // 1) Ligne locale par PK == localId ?
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

          // Déjà mappé → skip
          if (curRemote == remoteId &&
              (curLocal == null || curLocal == localId)) {
            continue;
          }

          // Mettre à jour seulement le linkage (pas de isDirty / pas de change_log ici)
          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId},
            where: 'id = ?',
            whereArgs: [localId],
          );

          // Supprimer un éventuel doublon PK==remoteId (on garde la PK locale)
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

        // 2) Pas de localId → essayé PK == remoteId
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

          // déjà mappé → skip
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

  // ---------------- Pass 2: upsert with conflict resolution ----------------

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
        final typeEntry = (_asStr(r['typeEntry']) ?? 'DEBIT').toUpperCase();
        final remoteSyncAt = _asUtc(r['syncAt']);
        if (maxAt == null || remoteSyncAt.isAfter(maxAt!)) maxAt = remoteSyncAt;

        // Base UPDATE payload (sans 'id')
        final baseData = <String, Object?>{
          'remoteId': remoteId,
          'localId': localId,
          'code': code,
          'createdBy': _asStr(r['createdBy']) ?? "NA",
          'description': desc,
          'typeEntry': typeEntry,
          'syncAt': remoteSyncAt.toIso8601String(),
        };

        // --- Chercher la cible sans jamais changer la PK ---
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
            final byIdEqRemote = await txn.query(
              entityTable,
              where: 'id = ?',
              whereArgs: [remoteId],
              limit: 1,
            );
            if (byIdEqRemote.isNotEmpty) target = byIdEqRemote.first;
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
          // UPDATE path — décider si on garde local (local.updatedAt > remote.syncAt)
          final localUpdatedAt = _parseLocalDate(target['updatedAt']);
          final keepLocal =
              localUpdatedAt != null && localUpdatedAt.isAfter(remoteSyncAt);

          final merged = Map<String, Object?>.from(baseData);
          if (keepLocal) {
            // on conserve les champs locaux; juste syncAt rafraîchi
            merged['code'] = target['code'];
            merged['description'] = target['description'];
            merged['typeEntry'] = target['typeEntry'];
            merged['isDirty'] = target['isDirty'];
          } else {
            // remote gagne → on nettoie isDirty
            merged['isDirty'] = 0;
          }

          // Faut-il logger ? (ignorer syncAt-only)
          final currentComparable = {
            for (final k in _materialKeys) k: target[k],
          };
          final mergedComparable = {
            for (final k in _materialKeys) k: merged[k],
          };
          final willLog = _differs(
            currentComparable,
            mergedComparable,
            _materialKeys,
          );

          // Toujours mettre à jour pour syncAt; log seulement si changement matériel
          await txn.update(
            entityTable,
            merged,
            where: 'id = ?',
            whereArgs: [target['id']],
          );

          if (willLog) {
            await upsertChangeLogPending(
              txn,
              entityTable: entityTable,
              entityId: (target['id'] ?? localId ?? remoteId).toString(),
              operation: 'UPDATE',
            );
          }

          upserts++;
        } else {
          // INSERT path — on crée la ligne et on ne log pas (source distante)
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
