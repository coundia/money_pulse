/* Change-log repository abstraction used by the outbox pusher. */
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';

abstract class ChangeLogRepository {
  Future<List<ChangeLogEntry>> findAll({String? status, int limit});
  Future<void> markAck(String id);
  Future<void> markPending(String id, {String? error});
  Future<void> delete(String id);
  Future<void> clearAll();

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
  Future<List<ChangeLogEntry>> findPendingByEntity(
    String entityTable, {
    int limit,
  });
}
