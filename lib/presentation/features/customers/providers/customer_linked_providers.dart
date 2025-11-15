// Providers for linked data to a customer: open debt + recent transactions.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/presentation/app/providers.dart';
import 'package:jaayko/presentation/features/debts/debt_repo_provider.dart';
import 'package:jaayko/domain/debts/entities/debt.dart';
import 'package:jaayko/domain/debts/repositories/debt_repository.dart';

final openDebtByCustomerProvider = FutureProvider.family<Debt?, String>((
  ref,
  customerId,
) async {
  final repo = ref.read(debtRepoProvider) as DebtRepository;
  return repo.findOpenByCustomer(customerId);
});

class LinkedTxnRow {
  final String id;
  final DateTime dateTransaction;
  final int amount;
  final String? description;
  final String typeEntry;
  final String? status;
  const LinkedTxnRow({
    required this.id,
    required this.dateTransaction,
    required this.amount,
    required this.description,
    required this.typeEntry,
    required this.status,
  });
}

final recentTransactionsOfCustomerProvider =
    FutureProvider.family<List<LinkedTxnRow>, String>((ref, customerId) async {
      final db = ref.read(dbProvider);
      return db.tx((txn) async {
        final rows = await txn.rawQuery(
          '''
      SELECT id, dateTransaction, amount, description, typeEntry, status
      FROM transaction_entry
      WHERE customerId = ? AND deletedAt IS NULL
      ORDER BY updatedAt DESC
      LIMIT 20
    ''',
          [customerId],
        );
        return rows.map((m) {
          return LinkedTxnRow(
            id: m['id'] as String,
            dateTransaction: DateTime.parse(m['dateTransaction'] as String),
            amount: (m['amount'] as int?) ?? 0,
            description: m['description'] as String?,
            typeEntry: (m['typeEntry'] as String?) ?? '',
            status: m['status'] as String?,
          );
        }).toList();
      });
    });
