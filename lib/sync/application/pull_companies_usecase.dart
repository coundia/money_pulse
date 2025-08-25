/* Pull use case for companies: pulls since last sync, adopts remote ids, upserts locally, then updates sync_state. */
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';

import '../infrastructure/pull_ports/company_pull_port_sqflite.dart';
import 'pull_port.dart';

class PullCompaniesUseCase implements PullPort {
  final CompanyPullPortSqflite port;
  final SyncApiClient api;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PullCompaniesUseCase(this.port, this.api, this.syncState, this.logger);

  @override
  Future<int> execute() async {
    final st = await syncState.findByTable(port.entityTable);
    final since =
        st?.lastSyncAt?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final items = await api.getCompaniesSince(since);
    if (items.isEmpty) {
      logger.info('Pull companies: nothing to pull since $since');
      return 0;
    }

    final adopted = await port.adoptRemoteIds(items);
    if (adopted > 0) {
      logger.info('Pull companies: adopted remote ids for $adopted row(s)');
    }

    final res = await port.upsertRemote(items);

    await syncState.upsert(
      entityTable: port.entityTable,
      lastSyncAt: res.maxSyncAt ?? DateTime.now().toUtc(),
    );

    logger.info('Pull companies: upserts=${res.upserts}');
    return res.upserts;
  }
}
