/* Abstraction for change_log repository with merge-upsert helpers for outbox. */
abstract class ChangeLogRepository {
  Future<List<dynamic>> findAll({String? status, int limit});

  Future<List<dynamic>> findPendingByEntity(String entityTable, {int limit});

  Future<Set<String>> findPendingIdsByEntity(String entityTable);

  Future<void> enqueue(
    String entityTable,
    String entityId,
    String operation,
    String payload,
  );

  Future<void> enqueueAll(
    String entityTable,
    List<({String entityId, String operation, String payload})> items,
  );

  Future<void> enqueueOrMergeAll(
    String entityTable,
    List<({String entityId, String operation, String payload})> items,
  );

  Future<void> markAck(String id);

  Future<void> markPending(String id, {String? error});

  Future<void> delete(String id);

  Future<void> clearAll();
}
