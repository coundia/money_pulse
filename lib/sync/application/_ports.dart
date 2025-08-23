/* Ports for repositories used by sync use cases. */
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';

abstract class CategorySyncPort {
  Future<List<Category>> findDirty({int limit});
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt);
}

abstract class AccountSyncPort {
  Future<List<Account>> findDirty({int limit});
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt);
}

abstract class TransactionSyncPort {
  Future<List<TransactionEntry>> findDirty({int limit});
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt);
}

abstract class UnitSyncPort {
  Future<List<Map<String, Object?>>> findDirty({int limit});
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt);
}

abstract class ProductSyncPort {
  Future<List<Map<String, Object?>>> findDirty({int limit});
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt);
}

abstract class TransactionItemSyncPort {
  Future<List<Map<String, Object?>>> findDirty({int limit});
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt);
}

abstract class CompanySyncPort {
  Future<List<Map<String, Object?>>> findDirty({int limit});
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt);
}

abstract class CustomerSyncPort {
  Future<List<Map<String, Object?>>> findDirty({int limit});
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt);
}

abstract class DebtSyncPort {
  Future<List<Map<String, Object?>>> findDirty({int limit});
  Future<void> markSynced(Iterable<String> ids, DateTime syncedAt);
}

abstract class StockLevelSyncPort {
  Future<List<Map<String, Object?>>> findDirty({int limit});
  Future<void> markSynced(Iterable<int> ids, DateTime syncedAt);
}

abstract class StockMovementSyncPort {
  Future<List<Map<String, Object?>>> findDirty({int limit});
  Future<void> markSynced(Iterable<int> ids, DateTime syncedAt);
}
