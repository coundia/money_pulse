/* Pull ports contracts: upsert remote payloads and compute max syncAt. */
typedef Json = Map<String, Object?>;

abstract class AccountPullPort {
  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(List<Json> items);
  String get entityTable;
}

abstract class ProductPullPort {
  String get entityTable;
  Future<int> adoptRemoteIds(List<Json> items);
  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(List<Json> items);
}

abstract class TransactionItemPullPort {
  String get entityTable;
  Future<int> adoptRemoteIds(List<Json> items);
  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(List<Json> items);
}

abstract class StockLevelPullPort {
  String get entityTable;
  Future<int> adoptRemoteIds(List<Json> items);
  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(List<Json> items);
}

abstract class StockMovementPullPort {
  String get entityTable;
  Future<int> adoptRemoteIds(List<Json> items);
  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(List<Json> items);
}

abstract class DebtPullPort {
  String get entityTable;
  Future<int> adoptRemoteIds(List<Json> items);
  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(List<Json> items);
}

abstract class AccountUserPullPort {
  String get entityTable; // should be 'account_users'
  Future<int> adoptRemoteIds(List<Json> items);
  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(List<Json> items);
}
