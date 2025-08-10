import '../entities/transaction_entry.dart';

abstract class TransactionRepository {
  Future<TransactionEntry> create(TransactionEntry entry);
  Future<void> update(TransactionEntry entry);
  Future<void> softDelete(String id);
  Future<TransactionEntry?> findById(String id);

  Future<List<TransactionEntry>> findRecentByAccount(
    String accountId, {
    int limit = 50,
  });
  Future<List<TransactionEntry>> findByAccountForMonth(
    String accountId,
    DateTime month, {
    String? typeEntry,
  });

  /// NEW: generic period query
  Future<List<TransactionEntry>> findByAccountBetween(
    String accountId,
    DateTime from,
    DateTime to, {
    String? typeEntry, // 'DEBIT' or 'CREDIT'
  });
}
