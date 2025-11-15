import 'package:jaayko/sync/infrastructure/sync_api_client.dart';
import 'package:jaayko/domain/sync/repositories/sync_state_repository.dart';
import 'package:jaayko/sync/infrastructure/sync_logger.dart';

import '../infrastructure/pull_ports/account_pull_port_sqflite.dart';
import 'pull_port.dart';

class PullAccountsUseCase implements PullPort {
  final AccountPullPortSqflite port;
  final SyncApiClient api;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PullAccountsUseCase(this.port, this.api, this.syncState, this.logger);

  @override
  Future<int> execute() async {
    // 1) Figure out "since"
    final st = await syncState.findByTable(port.entityTable);
    final since =
        st?.lastSyncAt?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    // 2) Pull from API
    final items = await api.getAccountsSince(since);
    if (items.isEmpty) {
      logger.info('Pull accounts: nothing to pull since $since');
      return 0;
    }

    // 3) First pass: adopt remote ids into local rows using localId
    final adopted = await port.adoptRemoteIds(items);
    if (adopted > 0) {
      logger.info('Pull accounts: adopted remote ids for $adopted row(s)');
    }

    // 4) Second pass: upsert/merge the data
    final res = await port.upsertRemote(items);

    // 5) Save sync_state
    await syncState.upsert(
      entityTable: port.entityTable,
      lastSyncAt: res.maxSyncAt ?? DateTime.now().toUtc(),
    );

    logger.info('Pull accounts: upserts=${res.upserts}');
    return res.upserts;
  }
}
