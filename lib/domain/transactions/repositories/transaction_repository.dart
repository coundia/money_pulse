import '../entities/transaction_entry.dart';

abstract class TransactionRepository {
  Future<TransactionEntry> create(TransactionEntry entry);
  Future<void> softDelete(String id);
  Future<List<TransactionEntry>> findRecentByAccount(
    String accountId, {
    int limit = 50,
  });
  Future<List<Map<String, Object?>>> spendingByCategoryLast30Days(
    String accountId,
  );
}
