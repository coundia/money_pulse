import 'package:jaayko/sync/infrastructure/sync_api_client.dart';
import 'package:jaayko/domain/sync/repositories/sync_state_repository.dart';
import 'package:jaayko/sync/infrastructure/sync_logger.dart';

import '../infrastructure/pull_ports/category_pull_port_sqflite.dart';
import 'pull_port.dart';

class PullCategoriesUseCase implements PullPort {
  final CategoryPullPortSqflite port;
  final SyncApiClient api;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PullCategoriesUseCase(this.port, this.api, this.syncState, this.logger);

  @override
  Future<int> execute() async {
    final st = await syncState.findByTable(port.entityTable);
    final since =
        st?.lastSyncAt?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final items = await api.getCategoriesSince(since);
    if (items.isEmpty) {
      logger.info('Pull categories: nothing to pull since $since');
      return 0;
    }

    final adopted = await port.adoptRemoteIds(items);
    if (adopted > 0) {
      logger.info('Pull categories: adopted remote ids for $adopted row(s)');
    }

    final res = await port.upsertRemote(items);

    await syncState.upsert(
      entityTable: port.entityTable,
      lastSyncAt: res.maxSyncAt ?? DateTime.now().toUtc(),
    );

    logger.info('Pull categories: upserts=${res.upserts}');
    return res.upserts;
  }
}
