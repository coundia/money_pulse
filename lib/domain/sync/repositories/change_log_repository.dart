import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';

abstract class ChangeLogRepository {
  Future<List<ChangeLogEntry>> findAll({String? status, int limit = 300});
  Future<List<ChangeLogEntry>> findPendingByEntity(
    String entityTable, {
    int limit = 200,
  });
  Future<Set<String>> findPendingIdsByEntity(String entityTable);

  /// Récupère une ligne par id (utile pour savoir entityTable/entityId).
  Future<ChangeLogEntry?> getById(String id);

  /// Laisse l’entrée en attente, incrémente attempts, renseigne error.
  Future<void> markPending(String id, {String? error});

  /// Marque l’entrée comme SYNC en supprimant toute autre ligne (entityTable, entityId, 'SYNC') qui ferait collision.
  Future<void> markSync(String id);
  Future<void> markSent(String id);
  Future<void> markAck(String id);

  /// Optionnel : statut FAILED si tu veux distinguer visuellement l’échec réseau.
  Future<void> markFailed(String id, {String? error});

  Future<void> delete(String id);
  Future<void> clearAll();

  /// Gardé pour compat legacy, **non utilisé** dans le mode “source de vérité”.
  Future<int> enqueueOrMergeAll(
    String entityTable,
    List<({String entityId, String operation, String payload})> items,
  );
}
