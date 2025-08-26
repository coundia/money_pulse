// Pull use case for debts.
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import '../infrastructure/pull_ports/debt_pull_port_sqflite.dart';

class PullDebtsUseCase {
  final DebtPullPortSqflite port;
  final SyncApiClient api;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PullDebtsUseCase(this.port, this.api, this.syncState, this.logger);

  Future<int> execute() async {
    final st = await syncState.findByTable(port.entityTable);
    final since =
        st?.lastSyncAt?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final items = await api.getDebtsSince(since);
    if (items.isEmpty) {
      logger.info('Pull debts: nothing since $since');
      return 0;
    }
    final adopted = await port.adoptRemoteIds(items);
    if (adopted > 0) logger.info('Pull debts: adopted $adopted');
    final res = await port.upsertRemote(items);
    await syncState.upsert(
      entityTable: port.entityTable,
      lastSyncAt: res.maxSyncAt ?? DateTime.now().toUtc(),
    );
    logger.info('Pull debts: upserts=${res.upserts}');
    return res.upserts;
  }
}
