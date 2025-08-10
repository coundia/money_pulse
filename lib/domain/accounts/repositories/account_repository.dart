import '../entities/account.dart';

abstract class AccountRepository {
  Future<Account> create(Account account);
  Future<void> update(Account account);
  Future<Account?> findById(String id);
  Future<Account?> findDefault();
  Future<List<Account>> findAllActive();
  Future<void> setDefault(String id);
  Future<void> softDelete(String id);
}
