import 'package:uuid/uuid.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/domain/transactions/repositories/transaction_repository.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';

class QuickAddTransactionUseCase {
  final TransactionRepository txRepo;
  final AccountRepository accRepo;

  QuickAddTransactionUseCase(this.txRepo, this.accRepo);

  /// Add a transaction quickly with optional [dateTransaction].
  Future<void> execute({
    required int amountCents,
    required bool isDebit,
    String? description,
    String? categoryId,
    DateTime? dateTransaction,
  }) async {
    final acc = await accRepo.findDefault();
    if (acc == null) {
      throw Exception('No default account');
    }
    final now = DateTime.now();
    final entry = TransactionEntry(
      id: const Uuid().v4(),
      remoteId: null,
      code: null,
      description: (description?.trim().isEmpty ?? true)
          ? null
          : description!.trim(),
      amount: amountCents,
      typeEntry: isDebit ? 'DEBIT' : 'CREDIT',
      dateTransaction: dateTransaction ?? now,
      status: null,
      entityName: null,
      entityId: null,
      accountId: acc.id,
      categoryId: categoryId,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncAt: null,
      version: 0,
      isDirty: true,
    );
    await txRepo.create(entry);
  }
}
