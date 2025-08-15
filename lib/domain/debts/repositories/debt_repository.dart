// Debt repository contract with txn-aware methods for atomic flows.
import 'package:sqflite/sqflite.dart';
import '../../debts/entities/debt.dart';

abstract class DebtRepository {
  Future<Debt?> findOpenByCustomer(String customerId);
  Future<Debt> create(Debt debt);
  Future<void> updateBalance(String id, int newBalance);
  Future<void> markUpdated(String id, DateTime when);
  Future<Debt> upsertOpenForCustomer(String customerId);

  Future<Debt?> findOpenByCustomerTx(Transaction txn, String customerId);
  Future<Debt> createTx(Transaction txn, Debt debt);
  Future<void> updateBalanceTx(Transaction txn, String id, int newBalance);
  Future<void> markUpdatedTx(Transaction txn, String id, DateTime when);
  Future<Debt> upsertOpenForCustomerTx(Transaction txn, String customerId);
}
