// Repository contract for accounts with optional DatabaseExecutor to support atomic transactions.
import 'package:sqflite/sqflite.dart';
import '../entities/account.dart';

abstract class AccountRepository {
  Future<Account> create(Account account, {DatabaseExecutor? exec});
  Future<void> update(Account account, {DatabaseExecutor? exec});
  Future<void> setDefault(String id, {DatabaseExecutor? exec});
  Future<void> softDelete(String id, {DatabaseExecutor? exec});

  Future<Account?> findById(String id);
  Future<Account?> findDefault();
  Future<List<Account>> findAllActive();
}
