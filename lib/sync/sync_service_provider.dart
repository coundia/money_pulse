/* Riverpod wiring for sync use cases using Sqflite adapters and logger. */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/infrastructure/sqflite_sync_ports.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:money_pulse/sync/application/push_categories_usecase.dart';
import 'package:money_pulse/sync/application/push_accounts_usecase.dart';
import 'package:money_pulse/sync/application/push_transactions_usecase.dart';
import 'package:money_pulse/sync/application/push_units_usecase.dart';
import 'package:money_pulse/sync/application/push_products_usecase.dart';
import 'package:money_pulse/sync/application/push_transaction_items_usecase.dart';
import 'package:money_pulse/sync/application/push_companies_usecase.dart';
import 'package:money_pulse/sync/application/push_customers_usecase.dart';
import 'package:money_pulse/sync/application/push_debts_usecase.dart';
import 'package:money_pulse/sync/application/push_stock_levels_usecase.dart';
import 'package:money_pulse/sync/application/push_stock_movements_usecase.dart';
import 'package:money_pulse/sync/application/sync_all_usecase.dart';
import 'package:money_pulse/presentation/app/base_uri_provider.dart';

final syncBaseUriProvider = Provider<String>(
  (ref) => ref.watch(baseUriProvider),
);

final categoryPushUseCaseProvider = Provider<PushCategoriesUseCase>((ref) {
  final api = ref.read(syncApiClientProvider(ref.watch(syncBaseUriProvider)));
  final db = ref.read(dbProvider).db;
  return PushCategoriesUseCase(CategorySyncPortSqflite(db), api);
});

final accountPushUseCaseProvider = Provider<PushAccountsUseCase>((ref) {
  final api = ref.read(syncApiClientProvider(ref.watch(syncBaseUriProvider)));
  final db = ref.read(dbProvider).db;
  return PushAccountsUseCase(AccountSyncPortSqflite(db), api);
});

final transactionPushUseCaseProvider = Provider<PushTransactionsUseCase>((ref) {
  final api = ref.read(syncApiClientProvider(ref.watch(syncBaseUriProvider)));
  final db = ref.read(dbProvider).db;
  return PushTransactionsUseCase(TransactionSyncPortSqflite(db), api);
});

final unitPushUseCaseProvider = Provider<PushUnitsUseCase>((ref) {
  final api = ref.read(syncApiClientProvider(ref.watch(syncBaseUriProvider)));
  final db = ref.read(dbProvider).db;
  return PushUnitsUseCase(UnitSyncPortSqflite(db), api);
});

final productPushUseCaseProvider = Provider<PushProductsUseCase>((ref) {
  final api = ref.read(syncApiClientProvider(ref.watch(syncBaseUriProvider)));
  final db = ref.read(dbProvider).db;
  return PushProductsUseCase(ProductSyncPortSqflite(db), api);
});

final transactionItemPushUseCaseProvider =
    Provider<PushTransactionItemsUseCase>((ref) {
      final api = ref.read(
        syncApiClientProvider(ref.watch(syncBaseUriProvider)),
      );
      final db = ref.read(dbProvider).db;
      return PushTransactionItemsUseCase(
        TransactionItemSyncPortSqflite(db),
        api,
      );
    });

final companyPushUseCaseProvider = Provider<PushCompaniesUseCase>((ref) {
  final api = ref.read(syncApiClientProvider(ref.watch(syncBaseUriProvider)));
  final db = ref.read(dbProvider).db;
  return PushCompaniesUseCase(CompanySyncPortSqflite(db), api);
});

final customerPushUseCaseProvider = Provider<PushCustomersUseCase>((ref) {
  final api = ref.read(syncApiClientProvider(ref.watch(syncBaseUriProvider)));
  final db = ref.read(dbProvider).db;
  return PushCustomersUseCase(CustomerSyncPortSqflite(db), api);
});

final debtPushUseCaseProvider = Provider<PushDebtsUseCase>((ref) {
  final api = ref.read(syncApiClientProvider(ref.watch(syncBaseUriProvider)));
  final db = ref.read(dbProvider).db;
  return PushDebtsUseCase(DebtSyncPortSqflite(db), api);
});

final stockLevelPushUseCaseProvider = Provider<PushStockLevelsUseCase>((ref) {
  final api = ref.read(syncApiClientProvider(ref.watch(syncBaseUriProvider)));
  final db = ref.read(dbProvider).db;
  return PushStockLevelsUseCase(StockLevelSyncPortSqflite(db), api);
});

final stockMovementPushUseCaseProvider = Provider<PushStockMovementsUseCase>((
  ref,
) {
  final api = ref.read(syncApiClientProvider(ref.watch(syncBaseUriProvider)));
  final db = ref.read(dbProvider).db;
  return PushStockMovementsUseCase(StockMovementSyncPortSqflite(db), api);
});

final syncAllUseCaseProvider = Provider<SyncAllUseCase>((ref) {
  final logger = ref.read(syncLoggerProvider);
  return SyncAllUseCase(
    categories: ref.read(categoryPushUseCaseProvider),
    accounts: ref.read(accountPushUseCaseProvider),
    transactions: ref.read(transactionPushUseCaseProvider),
    units: ref.read(unitPushUseCaseProvider),
    products: ref.read(productPushUseCaseProvider),
    items: ref.read(transactionItemPushUseCaseProvider),
    companies: ref.read(companyPushUseCaseProvider),
    customers: ref.read(customerPushUseCaseProvider),
    debts: ref.read(debtPushUseCaseProvider),
    stockLevels: ref.read(stockLevelPushUseCaseProvider),
    stockMovements: ref.read(stockMovementPushUseCaseProvider),
    logger: logger,
  );
});

Future<SyncSummary> syncAllTables(WidgetRef ref, {int batchSize = 200}) {
  final uc = ref.read(syncAllUseCaseProvider);
  return uc.syncAll(batchSize: batchSize);
}
