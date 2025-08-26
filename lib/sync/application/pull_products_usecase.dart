// Pulls product rows from remote and upserts into local DB using syncAt cursor.
import 'package:money_pulse/sync/application/pull_port.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import '../infrastructure/pull_ports/product_pull_port_sqflite.dart';

class PullProductsUseCase implements PullPort {
  final ProductPullPortSqflite port;
  final SyncApiClient api;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PullProductsUseCase(this.port, this.api, this.syncState, this.logger);

  @override
  Future<int> execute() async {
    final st = await syncState.findByTable(port.entityTable);
    final since =
        st?.lastSyncAt?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final items = await api.getProductsSince(since);
    if (items.isEmpty) {
      logger.info('Pull products: nothing to pull since $since');
      return 0;
    }

    final adopted = await port.adoptRemoteIds(items);
    if (adopted > 0) {
      logger.info('Pull products: adopted remote ids for $adopted row(s)');
    }

    final res = await port.upsertRemote(items);

    await syncState.upsert(
      entityTable: port.entityTable,
      lastSyncAt: res.maxSyncAt ?? DateTime.now().toUtc(),
    );

    logger.info('Pull products: upserts=${res.upserts}');
    return res.upserts;
  }
}
