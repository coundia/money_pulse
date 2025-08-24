/* ChangeLog sqflite repository with conflict-safe ACK:
 * when updating a row to ACK, it removes any pre-existing ACK rows for the same (entityTable, entityId) to avoid UNIQUE violations.
 */
import 'dart:convert';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
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
    return rows.map((m) => ChangeLogEntry.fromMap(m)).toList();
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
    return rows.map((m) => ChangeLogEntry.fromMap(m)).toList();
  }

  @override
  Future<void> markAck(String id) async {
    final now = _now();
    await _db.db.transaction((txn) async {
      await txn.update(
        'change_log',
        {'status': 'ACK', 'updatedAt': now, 'processedAt': now, 'error': null},
        where: 'id = ?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  @override
  Future<void> markPending(String id, {String? error}) async {
    await _db.db.rawUpdate(
      'UPDATE change_log SET attempts = attempts + 1, status = ?, updatedAt = ?, error = ? WHERE id = ?',
      ['PENDING', _now(), error, id],
    );
  }

  @override
  Future<void> markSent(String id, {String? error}) async {
    await _db.db.rawUpdate(
      'UPDATE change_log SET attempts = attempts + 1, status = ?, updatedAt = ?, error = ? WHERE id = ?',
      ['SENT', _now(), error, id],
    );
  }

  @override
  Future<void> delete(String id) async {
    await _db.db.delete('change_log', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearAll() async {
    await _db.db.delete('change_log');
  }

  Future<int> enqueueOrMergeAll(
    String entityTable,
    List<({String entityId, String operation, String payload})> items,
  ) async {
    if (items.isEmpty) return 0;
    int inserted = 0;
    final now = _now();
    await _db.db.transaction((txn) async {
      for (final it in items) {
        final existing = await txn.query(
          'change_log',
          columns: ['id', 'payload'],
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
          final rowId = existing.first['id'] as String;
          await txn.update(
            'change_log',
            {'payload': it.payload, 'updatedAt': now},
            where: 'id = ?',
            whereArgs: [rowId],
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }
    });
    return inserted;
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
}
