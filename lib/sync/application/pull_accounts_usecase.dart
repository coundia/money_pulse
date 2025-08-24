/* Pull accounts from remote /queries/account/syncAt and upsert locally, then advance sync_state. */
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import '../infrastructure/sync_logger.dart';
import '../infrastructure/sqflite_pull_ports.dart';
import 'pull_port.dart';

class PullAccountsUseCase implements PullPort {
  final AccountPullPortSqflite port;
  final SyncApiClient api;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PullAccountsUseCase(this.port, this.api, this.syncState, this.logger);

  @override
  Future<int> execute() async {
    final state = await syncState.findByTable(port.entityTable);
    final since = state?.lastSyncAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    logger.info('Pull ${port.entityTable}: since=$since');

    final items = await api.getAccountsSince(since);
    if (items.isEmpty) {
      logger.info('Pull ${port.entityTable}: none');
      return 0;
    }

    final res = await port.upsertRemote(items);
    if (res.maxSyncAt != null) {
      await syncState.upsert(
        entityTable: port.entityTable,
        lastSyncAt: res.maxSyncAt,
        lastCursor: null,
      );
    }
    logger.info('Pull ${port.entityTable}: upserts=${res.upserts}');
    return res.upserts;
  }
}
