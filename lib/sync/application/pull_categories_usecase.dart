/* Pull categories from remote /queries/category/syncAt and upsert locally, then advance sync_state. */
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import '../infrastructure/sqflite_sync_ports.dart';
import '../infrastructure/sync_logger.dart';
import '../infrastructure/category_pull_port_sqflite.dart';
import 'pull_port.dart';

class PullCategoriesUseCase implements PullPort {
  final CategorySyncPortSqflite port;
  final SyncApiClient api;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PullCategoriesUseCase(this.port, this.api, this.syncState, this.logger);

  @override
  Future<int> execute() async {
    final state = await syncState.findByTable(port.entityTable);
    final since =
        state?.lastSyncAt ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    logger.info('Pull ${port.entityTable}: since=$since');

    final items = await api.getCategoriesSince(since);
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
