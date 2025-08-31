// Use case to adjust an account balance and insert a matching transaction entry atomically.
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/accounts/repositories/account_repository.dart';
import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class AdjustBalanceUseCase {
  final AppDatabase db;
  final AccountRepository accountRepo;

  const AdjustBalanceUseCase({required this.db, required this.accountRepo});

  Future<Account> execute({
    required Account account,
    required int newBalanceCents,
    String? userNote,
  }) async {
    final before = account.balance;
    final after = newBalanceCents;
    final delta = after - before;
    if (delta == 0) return account;

    final now = DateTime.now();
    final updated = account.copyWith(
      balancePrev: account.balance,
      balance: after,
      updatedAt: now,
      isDirty: true,
    );

    await db.tx((txn) async {
      await accountRepo.update(updated, exec: txn as DatabaseExecutor);

      final idTx = const Uuid().v4();
      final idLog = const Uuid().v4();
      final typeEntry = delta > 0 ? 'CREDIT' : 'DEBIT';
      final amountAbs = delta.abs();

      final description = [
        'Ajustement de solde',
        '(avant: ${Formatters.majorRawFromMinor(before)}, après: ${Formatters.majorRawFromMinor(after)})',
        if (userNote != null && userNote.trim().isNotEmpty)
          '— ${userNote.trim()}',
      ].join(' ');

      await txn.insert('transaction_entry', <String, Object?>{
        'id': idTx,
        'accountId': updated.id,
        'typeEntry': typeEntry,
        'amount': amountAbs,
        'description': description,
        'dateTransaction': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'version': 0,
        'isDirty': 1,
        'deletedAt': null,
        'status': null,
        'code': null,
        'remoteId': null,
        'entityName': null,
        'entityId': null,
        'categoryId': null,
        'companyId': null,
        'customerId': null,
        'syncAt': null,
      }, conflictAlgorithm: ConflictAlgorithm.abort);

      await txn.rawInsert(
        'INSERT INTO change_log(id, entityTable, entityId, operation, payload, status, createdAt, updatedAt) '
        'VALUES(?,?,?,?,?,?,?,?) ',
        [
          idLog,
          'transaction_entry',
          idTx,
          'INSERT',
          null,
          'PENDING',
          now.toIso8601String(),
          now.toIso8601String(),
        ],
      );
    });

    return updated;
  }
}
