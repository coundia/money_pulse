import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';

import '../infrastructure/sqflite_pull_ports.dart';
import 'pull_port.dart';

class PullAccountsUseCase implements PullPort {
  final AccountPullPortSqflite port;
  final SyncApiClient api;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PullAccountsUseCase(this.port, this.api, this.syncState, this.logger);

  Future<int> execute() async {
    final st = await syncState.findByTable(port.entityTable);
    final since =
        st?.lastSyncAt?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final items = await api.getAccountsSince(since);
    if (items.isEmpty) return 0;

    final res = await port.upsertRemote(items);
    await syncState.upsert(
      entityTable: port.entityTable,
      lastSyncAt: res.maxSyncAt ?? DateTime.now().toUtc(),
    );
    logger.info('Pull accounts: upserts=${res.upserts}');
    return res.upserts;
  }
}
