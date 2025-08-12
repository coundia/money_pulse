import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:sqflite/sqflite.dart';

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
    // sqflite ne supporte pas l’incrément via Map => on passe par rawUpdate
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
