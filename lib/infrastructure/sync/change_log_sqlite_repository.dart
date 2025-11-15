import 'package:jaayko/infrastructure/db/app_database.dart';
import 'package:jaayko/domain/sync/entities/change_log_entry.dart';
import 'package:jaayko/domain/sync/repositories/change_log_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class ChangeLogRepositorySqflite implements ChangeLogRepository {
  final AppDatabase _db;
  ChangeLogRepositorySqflite(this._db);

  String _now() => DateTime.now().toIso8601String();

  @override
  Future<List<ChangeLogEntry>> findAll({
    String? status,
    int limit = 300,
  }) async {
    final rows = await _db.db.query(
      'change_log',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map(ChangeLogEntry.fromMap).toList();
  }

  @override
  Future<List<ChangeLogEntry>> findPendingByEntity(
    String entityTable, {
    int limit = 200,
  }) async {
    final rows = await _db.db.query(
      'change_log',
      where: 'status = ? AND entityTable = ?',
      whereArgs: ['PENDING', entityTable],
      orderBy: 'createdAt ASC',
      limit: limit,
    );
    return rows.map(ChangeLogEntry.fromMap).toList();
  }

  @override
  Future<Set<String>> findPendingIdsByEntity(String entityTable) async {
    final rows = await _db.db.query(
      'change_log',
      columns: ['entityId'],
      where: 'status = ? AND entityTable = ?',
      whereArgs: ['PENDING', entityTable],
    );
    return rows.map((m) => m['entityId'] as String).toSet();
  }

  @override
  Future<ChangeLogEntry?> getById(String id) async {
    final rows = await _db.db.query(
      'change_log',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ChangeLogEntry.fromMap(rows.first);
  }

  @override
  Future<void> markPending(String id, {String? error}) async {
    await _db.db.rawUpdate(
      'UPDATE change_log SET attempts = attempts + 1, status = ?, updatedAt = ?, error = ? WHERE id = ?',
      ['PENDING', _now(), error, id],
    );
  }

  // -------- transitions conflict-safe (supprime d'abord la cible) ----------

  Future<void> _transitionTo(
    String id,
    String newStatus, {
    String? error,
    bool setProcessed = false,
  }) async {
    final row = await _db.db.query(
      'change_log',
      columns: ['entityTable', 'entityId'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (row.isEmpty) return;
    final table = row.first['entityTable'] as String;
    final entityId = row.first['entityId'] as String;
    final now = _now();

    await _db.db.transaction((txn) async {
      // Supprimer toute autre ligne qui aurait déjà (table, entityId, newStatus)
      await txn.delete(
        'change_log',
        where: 'entityTable = ? AND entityId = ? AND status = ? AND id <> ?',
        whereArgs: [table, entityId, newStatus, id],
      );
      await txn.update(
        'change_log',
        {
          'status': newStatus,
          'updatedAt': now,
          'processedAt': setProcessed ? now : null,
          'error': error,
        },
        where: 'id = ?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  @override
  Future<void> markSync(String id) =>
      _transitionTo(id, 'SYNC', setProcessed: true);

  @override
  Future<void> markFailed(String id, {String? error}) =>
      _transitionTo(id, 'FAILED', error: error);

  // --------------------- utilitaires/legacy ---------------------------------

  @override
  Future<void> delete(String id) async {
    await _db.db.delete('change_log', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearAll() async {
    await _db.db.delete('change_log');
  }

  @override
  Future<int> enqueueOrMergeAll(
    String entityTable,
    List<({String entityId, String operation, String payload})> items,
  ) async {
    // Conservé pour compat, plus utilisé en mode “source de vérité”.
    if (items.isEmpty) return 0;
    int inserted = 0;
    final now = _now();
    await _db.db.transaction((txn) async {
      for (final it in items) {
        final existing = await txn.query(
          'change_log',
          columns: ['id'],
          where: 'entityTable = ? AND entityId = ? AND status = ?',
          whereArgs: [entityTable, it.entityId, 'PENDING'],
          limit: 1,
        );
        if (existing.isEmpty) {
          await txn.insert('change_log', {
            'id': const Uuid().v4(),
            'entityTable': entityTable,
            'entityId': it.entityId,
            'operation': it.operation,
            'payload': it.payload,
            'status': 'PENDING',
            'attempts': 0,
            'error': null,
            'createdAt': now,
            'updatedAt': now,
            'processedAt': null,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          inserted++;
        } else {
          await txn.update(
            'change_log',
            {'payload': it.payload, 'updatedAt': now},
            where: 'id = ?',
            whereArgs: [existing.first['id'] as String],
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }
    });
    return inserted;
  }

  @override
  Future<void> markAck(String id) =>
      _transitionTo(id, 'ACK', setProcessed: true);

  @override
  Future<void> markSent(String id) =>
      _transitionTo(id, 'SENT', setProcessed: true);
}
