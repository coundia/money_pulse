// Repository contract for AccountUser with CRUD-like actions including hard delete.
import 'package:jaayko/domain/accounts/entities/account_user.dart';

abstract class AccountUserRepository {
  Future<List<AccountUser>> listByAccount(String accountId, {String? q});
  Future<void> invite(AccountUser au);
  Future<void> updateRole(String id, String role);
  Future<void> revoke(String id);
  Future<AccountUser> accept(String id, {DateTime? when});
  Future<void> delete(String id);
}
