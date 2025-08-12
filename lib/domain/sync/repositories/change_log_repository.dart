import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';

abstract class ChangeLogRepository {
  Future<List<ChangeLogEntry>> findAll({String? status, int limit = 300});
  Future<void> markAck(String id);
  Future<void> markPending(String id, {String? error});
  Future<void> delete(String id);
  Future<void> clearAll();
}
