/* Pull ports contracts: how to upsert remote payloads into local storage and compute max syncAt. */
typedef Json = Map<String, Object?>;

abstract class AccountPullPort {
  Future<({int upserts, DateTime? maxSyncAt})> upsertRemote(List<Json> items);
  String get entityTable;
}
