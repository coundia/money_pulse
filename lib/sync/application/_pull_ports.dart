/* Pull ports contracts: how to upsert remote payloads into local storage and compute max syncAt. */
import '../../domain/transactions/entities/transaction_entry.dart';

typedef Json = Map<String, Object?>;

abstract class AccountPullPort {
  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(List<Json> items);
  String get entityTable;
}

abstract class TransactionSyncPort {
  Future<List<TransactionEntry>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);

  /// Utile pour reconstruire un payload depuis le change_log
  Future<TransactionEntry?> findById(String id);
}
