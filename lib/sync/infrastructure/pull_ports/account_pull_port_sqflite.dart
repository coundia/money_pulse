// Two-pass account pull port with deduplication by remoteId, local-vs-remote balance resolution, and material-change logging only on updates.
import 'package:sqflite/sqflite.dart';
import '../change_log_helper.dart';

typedef Json = Map<String, Object?>;

class AccountPullPortSqflite {
  final Database db;
  AccountPullPortSqflite(this.db);

  String get entityTable => 'account';

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
    if (v is DateTime) return v.toUtc();
    final s = v.toString();
    if (s.isEmpty) return null;
    final norm = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(norm)?.toUtc();
  }

  Object? _normForEq(Object? v) {
    if (v is num) return v.toInt();
    return v;
  }

  bool _hasAnyDiff(
    Map<String, Object?> a,
    Map<String, Object?> b,
    Iterable<String> keys,
  ) {
    for (final k in keys) {
      if (_normForEq(a[k]) != _normForEq(b[k])) return true;
    }
    return false;
  }

  static const _materialKeys = <String>{
    'remoteId',
    'localId',
    'code',
    'description',
    'currency',
    'typeAccount',
    'isDefault',
    'status',
    'balance',
    'balance_prev',
    'balance_blocked',
    'balance_init',
    'balance_goal',
    'balance_limit',
    'isDirty',
  };

  Future<Map<String, Object?>?> _rowById(DatabaseExecutor e, String id) async {
    final rows = await e.query(
      entityTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> _rowsByRemoteIdOrPk(
    DatabaseExecutor e,
    String remoteId,
  ) async {
    return e.query(
      entityTable,
      where: 'remoteId = ? OR id = ?',
      whereArgs: [remoteId, remoteId],
    );
  }

  Map<String, Object?> _pickPreferred(
    List<Map<String, Object?>> rows, {
    String? preferId,
    String? remoteId,
  }) {
    if (rows.isEmpty) return {};
    final byPrefer = preferId == null
        ? null
        : rows.where((r) => r['id']?.toString() == preferId).toList();
    if (byPrefer != null && byPrefer.isNotEmpty) return byPrefer.first;
    final byRemotePk = remoteId == null
        ? null
        : rows.where((r) => r['id']?.toString() == remoteId).toList();
    if (byRemotePk != null && byRemotePk.isNotEmpty) return byRemotePk.first;
    rows.sort((a, b) {
      final ad = _parseLocalDate(a['updatedAt']);
      final bd = _parseLocalDate(b['updatedAt']);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return rows.first;
  }

  Future<Map<String, Object?>?> _dedupeForRemote(
    DatabaseExecutor e,
    String remoteId, {
    String? preferId,
  }) async {
    final rows = await _rowsByRemoteIdOrPk(e, remoteId);
    if (rows.isEmpty) return null;
    final keep = _pickPreferred(rows, preferId: preferId, remoteId: remoteId);
    for (final r in rows) {
      if (r['id'].toString() == keep['id'].toString()) continue;
      await e.delete(entityTable, where: 'id = ?', whereArgs: [r['id']]);
    }
    return keep;
  }

  Future<int> adoptRemoteIds(List<Json> items) async {
    if (items.isEmpty) return 0;
    int changed = 0;

    await db.transaction((txn) async {
      for (final r in items) {
        final remoteId = _asStr(r['id']) ?? _asStr(r['remoteId']);
        final localId = _asStr(r['localId']);
        if (remoteId == null || localId == null) continue;

        final localRow = await _rowById(txn, localId);
        if (localRow != null) {
          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId},
            where: 'id = ?',
            whereArgs: [localId],
          );
          await _dedupeForRemote(txn, remoteId, preferId: localId);
          changed++;
          continue;
        }

        final dedupTarget = await _dedupeForRemote(
          txn,
          remoteId,
          preferId: localId,
        );
        if (dedupTarget != null) {
          await txn.update(
            entityTable,
            {'remoteId': remoteId, 'localId': localId},
            where: 'id = ?',
            whereArgs: [dedupTarget['id']],
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
        final currency = _asStr(r['currency']);
        final typeAccount = _asStr(r['typeAccount']);
        final isDefault =
            (r['isDefault'] == true) ||
            r['isDefault'] == 1 ||
            r['isDefault'] == 'true';
        final status = _asStr(r['status']);
        final remoteSyncAt = _asUtc(r['syncAt']);
        if (maxAt == null || remoteSyncAt.isAfter(maxAt!)) maxAt = remoteSyncAt;

        final baseData = <String, Object?>{
          'remoteId': remoteId,
          'localId': localId,
          'code': code,
          'description': desc,
          'createdBy': _asStr(r['createdBy']) ?? 'NA',
          'currency': currency,
          'typeAccount': typeAccount,
          'isDefault': isDefault ? 1 : 0,
          'status': status,
          'syncAt': remoteSyncAt.toIso8601String(),
        };

        final remoteBalances = <String, Object?>{
          'balance': _asInt(r['balance']),
          'balance_prev': _asInt(r['balancePrev']),
          'balance_blocked': _asInt(r['balanceBlocked']),
          'balance_init': _asInt(r['balanceInit']),
          'balance_goal': _asInt(r['balanceGoal']),
          'balance_limit': _asInt(r['balanceLimit']),
        };

        Map<String, Object?>? targetRow;

        if (remoteId != null) {
          targetRow = await _dedupeForRemote(txn, remoteId, preferId: localId);
        }

        if (targetRow == null && localId != null) {
          targetRow = await _rowById(txn, localId);
        }

        if (targetRow != null) {
          final localUpdatedAt = _parseLocalDate(targetRow['updatedAt']);
          final keepLocalBalances =
              localUpdatedAt != null && localUpdatedAt.isAfter(remoteSyncAt);

          final merged = Map<String, Object?>.from(baseData);
          if (keepLocalBalances) {
            merged.addAll({
              'balance': targetRow['balance'],
              'balance_prev': targetRow['balance_prev'],
              'balance_blocked': targetRow['balance_blocked'],
              'balance_init': targetRow['balance_init'],
              'balance_goal': targetRow['balance_goal'],
              'balance_limit': targetRow['balance_limit'],
              'isDirty': targetRow['isDirty'],
            });
          } else {
            merged.addAll(remoteBalances);
            merged['isDirty'] = 0;
          }

          final willLog = _hasAnyDiff(targetRow, merged, _materialKeys);

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
          final createdAt = remoteSyncAt.toIso8601String();
          final idToUse =
              localId ??
              remoteId ??
              DateTime.now().microsecondsSinceEpoch.toString();

          await txn.insert(entityTable, {
            'id': idToUse,
            ...baseData,
            ...remoteBalances,
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
