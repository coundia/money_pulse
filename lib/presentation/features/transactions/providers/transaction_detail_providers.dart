import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/categories/entities/category.dart';
import 'package:jaayko/domain/transactions/entities/transaction_item.dart';
import 'package:jaayko/presentation/app/providers.dart';

final categoryByIdProvider = FutureProvider.family<Category?, String?>((
  ref,
  id,
) async {
  if (id == null) return null;
  final repo = ref.read(categoryRepoProvider);
  return repo.findById(id);
});

final transactionItemsProvider =
    FutureProvider.family<List<TransactionItem>, String>((ref, txnId) async {
      final repo = ref.read(transactionItemRepoProvider);
      return repo.findByTransaction(txnId);
    });
