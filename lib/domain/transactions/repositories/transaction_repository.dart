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

  /// NEW: fetch transactions for a whole calendar month (local).
  /// If [typeEntry] is provided ('DEBIT' or 'CREDIT'), filter by it.
  Future<List<TransactionEntry>> findByAccountForMonth(
    String accountId,
    DateTime month, {
    String? typeEntry,
  });
}
