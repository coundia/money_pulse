import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show Database;

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/base_uri_provider.dart';

import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/infrastructure/sqflite_sync_ports.dart';
import 'package:money_pulse/sync/infrastructure/sqflite_pull_ports.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';

import 'package:money_pulse/sync/application/push_accounts_usecase.dart';
import 'package:money_pulse/sync/application/pull_accounts_usecase.dart';

import 'package:money_pulse/infrastructure/sync/change_log_sqlite_repository.dart';
import 'package:money_pulse/infrastructure/repositories/sync_state_repository_sqflite.dart';

// ---- base uri
final syncBaseUriProvider = Provider<String>(
  (ref) => ref.watch(baseUriProvider),
);
final _apiProvider = Provider<SyncApiClient>((ref) {
  return ref.read(syncApiClientProvider(ref.watch(syncBaseUriProvider)));
});

// ---- repos
final _changeLogRepoProvider = Provider<ChangeLogRepositorySqflite>((ref) {
  final db = ref.read(dbProvider);
  return ChangeLogRepositorySqflite(db);
});
final _syncStateRepoProvider = Provider<SyncStateRepositorySqflite>((ref) {
  final db = ref.read(dbProvider);
  return SyncStateRepositorySqflite(db);
});

// ---- push
final pushAccountsUseCaseProvider = Provider<PushAccountsUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final dbRaw = ref.read(dbProvider).db as Database;
  final port = AccountSyncPortSqflite(dbRaw);
  final changeLog = ref.read(_changeLogRepoProvider);
  final syncState = ref.read(_syncStateRepoProvider);
  return PushAccountsUseCase(port, api, changeLog, syncState, logger);
});

// ---- pull
final pullAccountsUseCaseProvider = Provider<PullAccountsUseCase>((ref) {
  final api = ref.read(_apiProvider);
  final logger = ref.read(syncLoggerProvider);
  final dbRaw = ref.read(dbProvider).db as Database;
  final port = AccountPullPortSqflite(dbRaw);
  final syncState = ref.read(_syncStateRepoProvider);
  return PullAccountsUseCase(port, api, syncState, logger);
});
