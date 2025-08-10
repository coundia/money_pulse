import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/domain/transactions/repositories/transaction_repository.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';

class QuickAddTransactionUseCase {
  final TransactionRepository txRepo;
  final AccountRepository accountRepo;
  QuickAddTransactionUseCase(this.txRepo, this.accountRepo);

  Future<TransactionEntry> execute({
    required int amountCents,
    required bool isDebit,
    String? description,
    String? categoryId,
    DateTime? when,
  }) async {
    final acc = await accountRepo.findDefault();
    if (acc == null) {
      throw StateError('No default account');
    }
    final now = when ?? DateTime.now();
    final e = TransactionEntry(
      id: const Uuid().v4(),
      amount: amountCents,
      typeEntry: isDebit ? 'DEBIT' : 'CREDIT',
      dateTransaction: now,
      description: description,
      accountId: acc.id,
      categoryId: categoryId,
      createdAt: now,
      updatedAt: now,
      version: 0,
      isDirty: true,
    );
    return await txRepo.create(e);
  }
}
