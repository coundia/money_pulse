/* Riverpod providers for push use cases including Company, plus SyncAll composition. */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show Database;

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/base_uri_provider.dart';

import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/infrastructure/sqflite_sync_ports.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';

import 'package:money_pulse/sync/application/push_categories_usecase.dart';
import 'package:money_pulse/sync/application/push_accounts_usecase.dart';
import 'package:money_pulse/sync/application/push_companies_usecase.dart';
import 'package:money_pulse/sync/application/push_customers_usecase.dart';
import 'package:money_pulse/sync/application/push_transactions_usecase.dart';
import 'package:money_pulse/sync/application/push_products_usecase.dart';
import 'package:money_pulse/sync/application/push_transaction_items_usecase.dart';
import 'package:money_pulse/sync/application/push_debts_usecase.dart';
import 'package:money_pulse/sync/application/push_stock_levels_usecase.dart';
import 'package:money_pulse/sync/application/push_stock_movements_usecase.dart';
import 'package:money_pulse/sync/application/sync_all_usecase.dart';

import '../infrastructure/repositories/sync_state_repository_sqflite.dart';
import '../infrastructure/sync/change_log_sqlite_repository.dart';
import 'infrastructure/sync_policy_provider.dart';

final syncBaseUriProvider = Provider<String>(
  (ref) => ref.watch(baseUriProvider),
);

final _apiProvider = Provider<SyncApiClient>((ref) {
  return ref.read(syncApiClientProvider(ref.watch(syncBaseUriProvider)));
});

final _changeLogRepoProvider = Provider<ChangeLogRepositorySqflite>((ref) {
  final db = ref.read(dbProvider);
  return ChangeLogRepositorySqflite(db);
});

final _syncStateRepoProvider = Provider<SyncStateRepositorySqflite>((ref) {
  final db = ref.read(dbProvider);
  return SyncStateRepositorySqflite(db);
});

final categoryPushUseCaseProvider = Provider<PushCategoriesUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final Database dbRaw = ref.read(dbProvider).db;
  final port = CategorySyncPortSqflite(dbRaw);
  final changeLog = ref.read(_changeLogRepoProvider);
  final syncState = ref.read(_syncStateRepoProvider);
  final logger = ref.read(syncLoggerProvider);
  return PushCategoriesUseCase(port, api, changeLog, syncState, logger);
});

final accountPushUseCaseProvider = Provider<PushAccountsUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final dbRaw = ref.read(dbProvider).db;
  final port = AccountSyncPortSqflite(dbRaw);
  final changeLog = ref.read(_changeLogRepoProvider);
  final syncState = ref.read(_syncStateRepoProvider);
  final logger = ref.read(syncLoggerProvider);
  return PushAccountsUseCase(
    port: port,
    api: api,
    changeLog: changeLog,
    syncState: syncState,
    logger: logger,
  );
});

final companyPushUseCaseProvider = Provider<PushCompaniesUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final dbRaw = ref.read(dbProvider).db;
  final port = CompanySyncPortSqflite(dbRaw);
  final changeLog = ref.read(_changeLogRepoProvider);
  final syncState = ref.read(_syncStateRepoProvider);
  final logger = ref.read(syncLoggerProvider);
  return PushCompaniesUseCase(port, api, changeLog, syncState, logger);
});

final customerPushUseCaseProvider = Provider<PushCustomersUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final dbRaw = ref.read(dbProvider).db;
  final port = CustomerSyncPortSqflite(dbRaw);
  final changeLog = ref.read(_changeLogRepoProvider);
  final syncState = ref.read(_syncStateRepoProvider);
  final logger = ref.read(syncLoggerProvider);
  return PushCustomersUseCase(port, api, changeLog, syncState, logger);
});

final transactionPushUseCaseProvider = Provider<PushTransactionsUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final Database dbRaw = ref.read(dbProvider).db;
  final port = TransactionSyncPortSqflite(dbRaw);
  final changeLog = ref.read(_changeLogRepoProvider);
  final syncState = ref.read(_syncStateRepoProvider);
  final logger = ref.read(syncLoggerProvider);
  return PushTransactionsUseCase(
    port,
    api,
    changeLog,
    syncState,
    logger,
    dbRaw,
  );
});

final productPushUseCaseProvider = Provider<PushProductsUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final dbRaw = ref.read(dbProvider).db;
  final port = ProductSyncPortSqflite(dbRaw);
  final changeLog = ref.read(_changeLogRepoProvider);
  final syncState = ref.read(_syncStateRepoProvider);
  final logger = ref.read(syncLoggerProvider);
  return PushProductsUseCase(
    port: port,
    api: api,
    changeLog: changeLog,
    syncState: syncState,
    logger: logger,
  );
});

final transactionItemPushUseCaseProvider =
    Provider<PushTransactionItemsUseCase>((ref) {
      final api = ref.read(_apiProvider);
      final dbRaw = ref.read(dbProvider).db;
      final port = TransactionItemSyncPortSqflite(dbRaw);
      final changeLog = ref.read(_changeLogRepoProvider);
      final syncState = ref.read(_syncStateRepoProvider);
      final logger = ref.read(syncLoggerProvider);
      return PushTransactionItemsUseCase(
        port: port,
        api: api,
        changeLog: changeLog,
        syncState: syncState,
        logger: logger,
      );
    });

final debtPushUseCaseProvider = Provider<PushDebtsUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final dbRaw = ref.read(dbProvider).db;
  final port = DebtSyncPortSqflite(dbRaw);
  final changeLog = ref.read(_changeLogRepoProvider);
  final syncState = ref.read(_syncStateRepoProvider);
  final logger = ref.read(syncLoggerProvider);
  return PushDebtsUseCase(
    port: port,
    api: api,
    changeLog: changeLog,
    syncState: syncState,
    logger: logger,
  );
});

final stockLevelPushUseCaseProvider = Provider<PushStockLevelsUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final dbRaw = ref.read(dbProvider).db;
  final port = StockLevelSyncPortSqflite(dbRaw);
  final changeLog = ref.read(_changeLogRepoProvider);
  final syncState = ref.read(_syncStateRepoProvider);
  final logger = ref.read(syncLoggerProvider);
  return PushStockLevelsUseCase(
    port: port,
    api: api,
    changeLog: changeLog,
    syncState: syncState,
    logger: logger,
  );
});

final stockMovementPushUseCaseProvider = Provider<PushStockMovementsUseCase>((
  ref,
) {
  final api = ref.read(_apiProvider);
  final dbRaw = ref.read(dbProvider).db;
  final port = StockMovementSyncPortSqflite(dbRaw);
  final changeLog = ref.read(_changeLogRepoProvider);
  final syncState = ref.read(_syncStateRepoProvider);
  final logger = ref.read(syncLoggerProvider);
  return PushStockMovementsUseCase(
    port: port,
    api: api,
    changeLog: changeLog,
    syncState: syncState,
    logger: logger,
  );
});

final syncAllUseCaseProvider = Provider<SyncAllUseCase>((ref) {
  final logger = ref.read(syncLoggerProvider);
  final policy = ref.read(syncPolicyProvider);
  return SyncAllUseCase(
    accounts: ref.read(accountPushUseCaseProvider),
    categories: ref.read(categoryPushUseCaseProvider),
    companies: ref.read(companyPushUseCaseProvider),
    customers: ref.read(customerPushUseCaseProvider),
    transactions: ref.read(transactionPushUseCaseProvider),
    products: ref.read(productPushUseCaseProvider),
    items: ref.read(transactionItemPushUseCaseProvider),
    debts: ref.read(debtPushUseCaseProvider),
    stockLevels: ref.read(stockLevelPushUseCaseProvider),
    stockMovements: ref.read(stockMovementPushUseCaseProvider),
    policy: policy,
    logger: logger,
  );
});

Future<SyncSummary> syncAllTables(WidgetRef ref, {int batchSize = 200}) {
  final uc = ref.read(syncAllUseCaseProvider);
  return uc.syncAll(batchSize: batchSize);
}
