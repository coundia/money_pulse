import 'dart:developer' as dev;

import 'package:uuid/uuid.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/domain/transactions/repositories/transaction_repository.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';

class QuickAddTransactionUseCase {
  final TransactionRepository txRepo;
  final AccountRepository accRepo;
  final AppDatabase db;

  QuickAddTransactionUseCase(this.txRepo, this.accRepo, this.db);

  Future<void> execute({
    required int amountCents,
    required bool isDebit,
    String? description,
    String? categoryId,
    DateTime? dateTransaction,
    String? accountId,
    String? companyId,
    String? customerId,
  }) async {
    final now = DateTime.now();

    try {
      if (amountCents <= 0) {
        throw ArgumentError.value(amountCents, 'amountCents', 'must be > 0');
      }

      final acc = accountId != null
          ? await accRepo.findById(accountId)
          : await accRepo.findDefault();
      if (acc == null) {
        throw StateError('No default account found');
      }

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
        companyId: companyId,
        customerId: customerId,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        syncAt: null,
        version: 0,
        isDirty: true,
      );

      await txRepo.create(entry);
    } catch (e, st) {
      dev.log(
        'QuickAddTransactionUseCase.execute failed',
        name: 'QuickAddTransaction',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
