import 'package:jaayko/infrastructure/db/app_database.dart';
import 'package:jaayko/domain/sync/entities/sync_state.dart';
import 'package:jaayko/domain/sync/repositories/sync_state_repository.dart';
import 'package:sqflite/sqflite.dart';

class SyncStateRepositorySqflite implements SyncStateRepository {
  final AppDatabase _db;
  SyncStateRepositorySqflite(this._db);

  String _now() => DateTime.now().toIso8601String();

  @override
  Future<List<SyncState>> findAll({int limit = 200}) async {
    final rows = await _db.db.query(
      'sync_state',
      orderBy: 'entityTable ASC',
      limit: limit,
    );
    return rows.map(SyncState.fromMap).toList();
  }

  @override
  Future<SyncState?> findByTable(String entityTable) async {
    final rows = await _db.db.query(
      'sync_state',
      where: 'entityTable = ?',
      whereArgs: [entityTable],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SyncState.fromMap(rows.first);
  }

  @override
  Future<void> upsert({
    required String entityTable,
    DateTime? lastSyncAt,
    String? lastCursor,
  }) async {
    final now = _now();
    await _db.db.insert('sync_state', {
      'entityTable': entityTable,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
      'lastCursor': lastCursor,
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await _db.db.update(
      'sync_state',
      {
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'lastCursor': lastCursor,
        'updatedAt': now,
      },
      where: 'entityTable = ?',
      whereArgs: [entityTable],
    );
  }

  @override
  Future<void> updateCursor(String entityTable, String? cursor) async {
    await _db.db.update(
      'sync_state',
      {'lastCursor': cursor, 'updatedAt': _now()},
      where: 'entityTable = ?',
      whereArgs: [entityTable],
    );
  }

  @override
  Future<void> reset(String entityTable) async {
    await _db.db.update(
      'sync_state',
      {'lastSyncAt': null, 'lastCursor': null, 'updatedAt': _now()},
      where: 'entityTable = ?',
      whereArgs: [entityTable],
    );
  }

  @override
  Future<void> delete(String entityTable) async {
    await _db.db.delete(
      'sync_state',
      where: 'entityTable = ?',
      whereArgs: [entityTable],
    );
  }

  @override
  Future<void> clearAll() async {
    await _db.db.delete('sync_state');
  }
}
