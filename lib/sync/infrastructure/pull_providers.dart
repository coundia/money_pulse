/* Riverpod wiring for pull use cases and pull-all orchestration. */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show Database;

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/base_uri_provider.dart';

import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:money_pulse/sync/application/pull_all_usecase.dart';
import 'package:money_pulse/sync/application/pull_accounts_usecase.dart';
import 'package:money_pulse/sync/infrastructure/sqflite_pull_ports.dart';
import 'package:money_pulse/sync/infrastructure/sync_policy_provider.dart';

import '../../infrastructure/repositories/sync_state_repository_sqflite.dart';

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

final pullAllUseCaseProvider = Provider<PullAllUseCase>((ref) {
  final policy = ref.read(syncPolicyProvider);
  final logger = ref.read(syncLoggerProvider);
  return PullAllUseCase(
    accounts: ref.read(pullAccountsUseCaseProvider),
    categories: null,
    units: null,
    companies: null,
    products: null,
    customers: null,
    debts: null,
    stockLevels: null,
    stockMovements: null,
    transactions: null,
    items: null,
    policy: policy,
    logger: logger,
  );
});

Future<PullSummary> pullAllTables(WidgetRef ref) {
  final uc = ref.read(pullAllUseCaseProvider);
  return uc.pullAll();
}
