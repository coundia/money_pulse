import 'package:jaayko/domain/transactions/entities/transaction_item.dart';

abstract class TransactionItemRepository {
  Future<List<TransactionItem>> findByTransaction(String transactionId);
  Future<TransactionItem?> findById(String id);
  Future<String> create(TransactionItem item);
  Future<void> update(TransactionItem item);
  Future<void> softDelete(String id, {DateTime? at});
  Future<void> softDeleteByTransaction(String transactionId, {DateTime? at});
}
