/* Repository contract for account sharing operations. */
import 'package:money_pulse/domain/accounts/entities/account_user.dart';

abstract class AccountUserRepository {
  Future<List<AccountUser>> listByAccount(String accountId, {String? q});
  Future<void> invite(AccountUser accountUser);
  Future<void> updateRole(String id, String role);
  Future<void> revoke(String id);
  Future<AccountUser> accept(String id, {DateTime? when});
}
