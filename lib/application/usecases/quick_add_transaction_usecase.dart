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
    String? accountId, // optional: if null, uses default account
    String? companyId, // ✅ optional
    String? customerId, // ✅ optional
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
      companyId: companyId, // ✅ persisted even if null
      customerId: customerId, // ✅ persisted even if null
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncAt: null,
      version: 0,
      isDirty: true,
    );

    await db.tx((txn) async {
      // 1) Insert transaction
      await txRepo.create(entry); // repo ne doit pas modifier le solde

      // 2) Update account balance
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

      // 3) change_log
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
