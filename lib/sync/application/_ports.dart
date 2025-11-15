import 'package:jaayko/domain/accounts/entities/account.dart';
import 'package:jaayko/domain/categories/entities/category.dart';

import '../../domain/accounts/entities/account_user.dart';
import '../../domain/company/entities/company.dart';
import '../../domain/customer/entities/customer.dart';
import '../../domain/stock/entities/stock_level.dart';
import '../../domain/debts/entities/debt.dart';
import '../../domain/products/entities/product.dart';
import '../../domain/stock/entities/stock_level.dart';
import '../../domain/stock/entities/stock_movement.dart';
import '../../domain/transactions/entities/transaction_entry.dart';
import '../../domain/transactions/entities/transaction_item.dart';

abstract class AccountSyncPort {
  Future<List<Account>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);

  Future<Account?> findById(String id);
}

abstract class CategorySyncPort {
  Future<List<Category>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);

  Future<Category?> findById(String id);
}

abstract class CustomerSyncPort {
  Future<List<Customer>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);
  Future<Customer?> findById(String id);
}

abstract class CompanySyncPort {
  Future<List<Company>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);
  Future<Company?> findById(String id);
}

abstract class TransactionSyncPort {
  Future<List<TransactionEntry>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);

  Future<TransactionEntry?> findById(String id);
}

abstract class ProductSyncPort {
  Future<List<Product>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);
  Future<Product?> findById(String id);
}

abstract class TransactionItemSyncPort {
  Future<List<TransactionItem>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);
  Future<TransactionItem?> findById(String id);
}

abstract class StockLevelSyncPort {
  Future<List<StockLevel>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);
  Future<StockLevel?> findById(String id);
}

abstract class StockMovementSyncPort {
  Future<List<StockMovement>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);
  Future<StockMovement?> findById(String id);
}

abstract class DebtSyncPort {
  Future<List<Debt>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);
  Future<Debt?> findById(String id);
}

abstract class AccountUserSyncPort {
  Future<List<AccountUser>> findDirty({int limit = 200});
  Future<void> markSynced(Iterable<String> ids, DateTime at);
  Future<AccountUser?> findById(String id);
}
