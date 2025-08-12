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

  /// Add a transaction quickly.
  /// - isDebit = true  => DEBIT (expense)  => balance -= amount
  /// - isDebit = false => CREDIT (income)  => balance += amount
  Future<void> execute({
    required int amountCents,
    required bool isDebit,
    String? description,
    String? categoryId,
    DateTime? dateTransaction,
    String? accountId, // <- OPTIONAL: if null, uses default account
  }) async {
    final now = DateTime.now();
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
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncAt: null,
      version: 0,
      isDirty: true,
    );

    await db.tx((txn) async {
      // 1) Insert the transaction (via repository if it supports external txn)
      await txRepo.create(
        entry,
      ); // ensure this does NOT change balance internally

      // 2) Update account balance with correct sign
      final delta = isDebit ? -amountCents : amountCents;
      final newBalance = acc.balance + delta;

      await txn.update(
        'account',
        {
          'balance': newBalance,
          'updatedAt': now.toIso8601String(),
          'isDirty': 1,
          'version': acc.version + 1,
        },
        where: 'id=?',
        whereArgs: [acc.id],
      );

      // 3) Upsert change_log for the transaction (optional but recommended)
      final logId = const Uuid().v4();
      await txn.rawInsert(
        '''
        INSERT INTO change_log(
          id, entityTable, entityId, operation, payload, status, attempts, error, createdAt, updatedAt, processedAt
        )
        VALUES(?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(entityTable, entityId, status) DO UPDATE SET
          operation=excluded.operation,
          payload=excluded.payload,
          updatedAt=excluded.updatedAt
        ''',
        [
          logId,
          'transaction_entry',
          entry.id,
          'INSERT',
          null,
          'PENDING',
          0,
          null,
          now.toIso8601String(),
          now.toIso8601String(),
          null,
        ],
      );
    });
  }
}
