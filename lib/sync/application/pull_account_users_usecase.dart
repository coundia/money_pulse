/* Pull use case for account_users: cursor by syncAt + upsert. */
import 'package:jaayko/sync/application/pull_port.dart';
import 'package:jaayko/sync/infrastructure/sync_api_client.dart';
import 'package:jaayko/sync/infrastructure/sync_logger.dart';
import 'package:jaayko/domain/sync/repositories/sync_state_repository.dart';
import '../infrastructure/pull_ports/account_user_pull_port_sqflite.dart';

class PullAccountUsersUseCase implements PullPort {
  final AccountUserPullPortSqflite port;
  final SyncApiClient api;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PullAccountUsersUseCase(this.port, this.api, this.syncState, this.logger);

  @override
  Future<int> execute() async {
    final st = await syncState.findByTable(port.entityTable);
    final since =
        st?.lastSyncAt?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final items = await api.getAccountUsersSince(since);
    if (items.isEmpty) {
      logger.info('Pull account_users: nothing to pull since $since');
      return 0;
    }

    final adopted = await port.adoptRemoteIds(items);
    if (adopted > 0) {
      logger.info('Pull account_users: adopted remote ids for $adopted row(s)');
    }

    final res = await port.upsertRemote(items);

    await syncState.upsert(
      entityTable: port.entityTable,
      lastSyncAt: res.maxSyncAt ?? DateTime.now().toUtc(),
    );

    logger.info('Pull account_users: upserts=${res.upserts}');
    return res.upserts;
  }
}
