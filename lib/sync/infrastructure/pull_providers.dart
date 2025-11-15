/* Riverpod providers for pull use cases, now includes accountUser and wires it into PullAllUseCase. */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show Database;

import 'package:jaayko/presentation/app/providers.dart';
import 'package:jaayko/presentation/app/base_uri_provider.dart';

import 'package:jaayko/sync/infrastructure/sync_api_client.dart';
import 'package:jaayko/sync/infrastructure/sync_logger.dart';
import 'package:jaayko/sync/application/pull_all_usecase.dart';
import 'package:jaayko/sync/application/pull_accounts_usecase.dart';
import 'package:jaayko/sync/application/pull_categories_usecase.dart';
import 'package:jaayko/sync/application/pull_companies_usecase.dart';
import 'package:jaayko/sync/application/pull_customers_usecase.dart';
import 'package:jaayko/sync/application/pull_transactions_usecase.dart';
import 'package:jaayko/sync/application/pull_products_usecase.dart';
import 'package:jaayko/sync/application/pull_transaction_items_usecase.dart';
import 'package:jaayko/sync/application/pull_debts_usecase.dart';
import 'package:jaayko/sync/application/pull_stock_levels_usecase.dart';
import 'package:jaayko/sync/application/pull_stock_movements_usecase.dart';
import 'package:jaayko/sync/application/pull_account_users_usecase.dart';
import 'package:jaayko/sync/infrastructure/sync_policy_provider.dart';

import '../../infrastructure/repositories/sync_state_repository_sqflite.dart';
import '../application/pull_port.dart';
import 'pull_ports/account_pull_port_sqflite.dart';
import 'pull_ports/category_pull_port_sqflite.dart';
import 'pull_ports/company_pull_port_sqflite.dart';
import 'pull_ports/customer_pull_port_sqflite.dart';
import 'pull_ports/transaction_pull_port_sqflite.dart';
import 'pull_ports/product_pull_port_sqflite.dart';
import 'pull_ports/transaction_item_pull_port_sqflite.dart';
import 'pull_ports/debt_pull_port_sqflite.dart';
import 'pull_ports/stock_level_pull_port_sqflite.dart';
import 'pull_ports/stock_movement_pull_port_sqflite.dart';
import 'pull_ports/account_user_pull_port_sqflite.dart';

final pullBaseUriProvider = Provider<String>(
  (ref) => ref.watch(baseUriProvider),
);

final _apiProvider = Provider<SyncApiClient>((ref) {
  return ref.read(syncApiClientProvider(ref.watch(pullBaseUriProvider)));
});

final _syncStateRepoProvider = Provider<SyncStateRepositorySqflite>((ref) {
  final db = ref.read(dbProvider);
  return SyncStateRepositorySqflite(db);
});

final pullAccountsUseCaseProvider = Provider<PullAccountsUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final db = ref.read(dbProvider).db as Database;
  final port = AccountPullPortSqflite(db);
  final syncState = ref.read(_syncStateRepoProvider);
  return PullAccountsUseCase(port, api, syncState, logger);
});

final pullCategoriesUseCaseProvider = Provider<PullCategoriesUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final db = ref.read(dbProvider).db as Database;
  final port = CategoryPullPortSqflite(db);
  final syncState = ref.read(_syncStateRepoProvider);
  return PullCategoriesUseCase(port, api, syncState, logger);
});

final pullCompaniesUseCaseProvider = Provider<PullCompaniesUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final db = ref.read(dbProvider).db as Database;
  final port = CompanyPullPortSqflite(db);
  final syncState = ref.read(_syncStateRepoProvider);
  return PullCompaniesUseCase(port, api, syncState, logger);
});

final pullCustomersUseCaseProvider = Provider<PullCustomersUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final db = ref.read(dbProvider).db as Database;
  final port = CustomerPullPortSqflite(db);
  final syncState = ref.read(_syncStateRepoProvider);
  return PullCustomersUseCase(port, api, syncState, logger);
});

final pullTransactionsUseCaseProvider = Provider<PullTransactionsUseCase>((
  ref,
) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final db = ref.read(dbProvider).db as Database;
  final port = TransactionPullPortSqflite(db);
  final syncState = ref.read(_syncStateRepoProvider);
  return PullTransactionsUseCase(port, api, syncState, logger);
});

final pullProductsUseCaseProvider = Provider<PullPort>((ref) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final db = ref.read(dbProvider).db as Database;
  final port = ProductPullPortSqflite(db);
  final syncState = ref.read(_syncStateRepoProvider);
  return PullProductsUseCase(port, api, syncState, logger);
});

final pullTransactionItemsUseCaseProvider = Provider<PullPort>((ref) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final db = ref.read(dbProvider).db as Database;
  final port = TransactionItemPullPortSqflite(db);
  final syncState = ref.read(_syncStateRepoProvider);
  return PullTransactionItemsUseCase(port, api, syncState, logger);
});

final pullDebtsUseCaseProvider = Provider<PullPort>((ref) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final db = ref.read(dbProvider).db as Database;
  final port = DebtPullPortSqflite(db);
  final syncState = ref.read(_syncStateRepoProvider);
  return PullDebtsUseCase(port, api, syncState, logger);
});

final pullStockLevelsUseCaseProvider = Provider<PullPort>((ref) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final db = ref.read(dbProvider).db as Database;
  final port = StockLevelPullPortSqflite(db);
  final syncState = ref.read(_syncStateRepoProvider);
  return PullStockLevelsUseCase(port, api, syncState, logger);
});

final pullStockMovementsUseCaseProvider = Provider<PullPort>((ref) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final db = ref.read(dbProvider).db as Database;
  final port = StockMovementPullPortSqflite(db);
  final syncState = ref.read(_syncStateRepoProvider);
  return PullStockMovementsUseCase(port, api, syncState, logger);
});

final pullAccountUsersUseCaseProvider = Provider<PullPort>((ref) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final db = ref.read(dbProvider).db as Database;
  final port = AccountUserPullPortSqflite(db);
  final syncState = ref.read(_syncStateRepoProvider);
  return PullAccountUsersUseCase(port, api, syncState, logger);
});

final pullAllUseCaseProvider = Provider<PullAllUseCase>((ref) {
  final policy = ref.read(syncPolicyProvider);
  final logger = ref.read(syncLoggerProvider);
  return PullAllUseCase(
    accounts: ref.read(pullAccountsUseCaseProvider),
    categories: ref.read(pullCategoriesUseCaseProvider),
    companies: ref.read(pullCompaniesUseCaseProvider),
    customers: ref.read(pullCustomersUseCaseProvider),
    transactions: ref.read(pullTransactionsUseCaseProvider),
    products: ref.read(pullProductsUseCaseProvider),
    items: ref.read(pullTransactionItemsUseCaseProvider),
    debts: ref.read(pullDebtsUseCaseProvider),
    stockLevels: ref.read(pullStockLevelsUseCaseProvider),
    stockMovements: ref.read(pullStockMovementsUseCaseProvider),
    accountUsers: ref.read(pullAccountUsersUseCaseProvider),
    policy: policy,
    logger: logger,
  );
});

Future<PullSummary> pullAllTables(WidgetRef ref) {
  final uc = ref.read(pullAllUseCaseProvider);
  return uc.pullAll();
}
