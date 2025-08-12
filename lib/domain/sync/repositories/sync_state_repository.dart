import 'package:money_pulse/domain/sync/entities/sync_state.dart';

abstract class SyncStateRepository {
  Future<List<SyncState>> findAll({int limit});
  Future<SyncState?> findByTable(String entityTable);

  /// Insert or update a row for an entity table.
  Future<void> upsert({
    required String entityTable,
    DateTime? lastSyncAt,
    String? lastCursor,
  });

  /// Only update cursor (and touch updatedAt).
  Future<void> updateCursor(String entityTable, String? cursor);

  /// Reset sync markers for a table (null lastSyncAt & lastCursor).
  Future<void> reset(String entityTable);

  /// Delete a row.
  Future<void> delete(String entityTable);

  /// Delete ALL rows (debug).
  Future<void> clearAll();
}
