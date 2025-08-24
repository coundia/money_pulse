/* SQLite ChangeLog repository with UPSERT semantics on (entityTable, entityId, status). */
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
      orderBy: 'updatedAt ASC, createdAt ASC',
      limit: limit,
    );
    return rows.map(ChangeLogEntry.fromMap).toList();
  }

  @override
  Future<void> enqueue(
    String entityTable,
    String entityId,
    String operation,
    String payload,
  ) async {
    final now = _now();
    await _db.db.transaction((txn) async {
      try {
        await txn.insert('change_log', {
          'id': const Uuid().v4(),
          'entityTable': entityTable,
          'entityId': entityId,
          'operation': operation,
          'payload': payload,
          'status': 'PENDING',
          'attempts': 0,
          'error': null,
          'createdAt': now,
          'updatedAt': now,
          'processedAt': null,
        }, conflictAlgorithm: ConflictAlgorithm.abort);
      } on DatabaseException catch (e) {
        final msg = e.toString();
        final isUnique = msg.contains('UNIQUE constraint failed');
        if (!isUnique) rethrow;
        await txn.update(
          'change_log',
          {
            'operation': operation,
            'payload': payload,
            'status': 'PENDING',
            'attempts': 0,
            'error': null,
            'updatedAt': now,
            'processedAt': null,
          },
          where: 'entityTable = ? AND entityId = ? AND status = ?',
          whereArgs: [entityTable, entityId, 'PENDING'],
        );
      }
    });
  }

  @override
  Future<void> enqueueAll(
    String entityTable,
    List<({String entityId, String operation, String payload})> items,
  ) async {
    if (items.isEmpty) return;
    final now = _now();
    await _db.db.transaction((txn) async {
      for (final it in items) {
        try {
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
          }, conflictAlgorithm: ConflictAlgorithm.abort);
        } on DatabaseException catch (e) {
          final msg = e.toString();
          final isUnique = msg.contains('UNIQUE constraint failed');
          if (!isUnique) rethrow;
          await txn.update(
            'change_log',
            {
              'operation': it.operation,
              'payload': it.payload,
              'status': 'PENDING',
              'attempts': 0,
              'error': null,
              'updatedAt': now,
              'processedAt': null,
            },
            where: 'entityTable = ? AND entityId = ? AND status = ?',
            whereArgs: [entityTable, it.entityId, 'PENDING'],
          );
        }
      }
    });
  }

  @override
  Future<void> markAck(String id) async {
    final now = _now();
    await _db.db.update(
      'change_log',
      {'status': 'ACK', 'updatedAt': now, 'processedAt': now, 'error': null},
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> markPending(String id, {String? error}) async {
    await _db.db.rawUpdate(
      'UPDATE change_log '
      'SET attempts = attempts + 1, status = ?, updatedAt = ?, error = ? '
      'WHERE id = ?',
      ['PENDING', _now(), error, id],
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
}
