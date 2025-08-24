import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

abstract class AccountSyncPort {
  Future<List<Account>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);

  /// Ajouté : utile pour (re)construire un payload depuis change_log
  Future<Account?> findById(String id);
}

abstract class CategorySyncPort {
  Future<List<Category>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);

  /// Ajouté
  Future<Category?> findById(String id);
}
