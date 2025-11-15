// Pulls stock levels from remote and upserts into local DB using syncAt cursor.
import 'package:jaayko/sync/application/pull_port.dart';
import 'package:jaayko/sync/infrastructure/sync_api_client.dart';
import 'package:jaayko/sync/infrastructure/sync_logger.dart';
import 'package:jaayko/domain/sync/repositories/sync_state_repository.dart';
import '../infrastructure/pull_ports/stock_level_pull_port_sqflite.dart';

class PullStockLevelsUseCase implements PullPort {
  final StockLevelPullPortSqflite port;
  final SyncApiClient api;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PullStockLevelsUseCase(this.port, this.api, this.syncState, this.logger);

  @override
  Future<int> execute() async {
    final st = await syncState.findByTable(port.entityTable);
    final since =
        st?.lastSyncAt?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final items = await api.getStockLevelsSince(since);
    if (items.isEmpty) {
      logger.info('Pull stockLevels: nothing to pull since $since');
      return 0;
    }

    final adopted = await port.adoptRemoteIds(items);
    if (adopted > 0) {
      logger.info('Pull stockLevels: adopted remote ids for $adopted row(s)');
    }

    final res = await port.upsertRemote(items);

    await syncState.upsert(
      entityTable: port.entityTable,
      lastSyncAt: res.maxSyncAt ?? DateTime.now().toUtc(),
    );

    logger.info('Pull stockLevels: upserts=${res.upserts}');
    return res.upserts;
  }
}
