// Pull use case for stock levels.
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import '../infrastructure/pull_ports/stock_level_pull_port_sqflite.dart';

class PullStockLevelsUseCase {
  final StockLevelPullPortSqflite port;
  final SyncApiClient api;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PullStockLevelsUseCase(this.port, this.api, this.syncState, this.logger);

  Future<int> execute() async {
    final st = await syncState.findByTable(port.entityTable);
    final since =
        st?.lastSyncAt?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final items = await api.getStockLevelsSince(since);
    if (items.isEmpty) {
      logger.info('Pull stock levels: nothing since $since');
      return 0;
    }
    final adopted = await port.adoptRemoteIds(items);
    if (adopted > 0) logger.info('Pull stock levels: adopted $adopted');
    final res = await port.upsertRemote(items);
    await syncState.upsert(
      entityTable: port.entityTable,
      lastSyncAt: res.maxSyncAt ?? DateTime.now().toUtc(),
    );
    logger.info('Pull stock levels: upserts=${res.upserts}');
    return res.upserts;
  }
}
