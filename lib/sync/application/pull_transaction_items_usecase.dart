// Pull use case for transaction items.
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import '../infrastructure/pull_ports/transaction_item_pull_port_sqflite.dart';

class PullTransactionItemsUseCase {
  final TransactionItemPullPortSqflite port;
  final SyncApiClient api;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PullTransactionItemsUseCase(this.port, this.api, this.syncState, this.logger);

  Future<int> execute() async {
    final st = await syncState.findByTable(port.entityTable);
    final since =
        st?.lastSyncAt?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final items = await api.getTransactionItemsSince(since);
    if (items.isEmpty) {
      logger.info('Pull items: nothing since $since');
      return 0;
    }
    final adopted = await port.adoptRemoteIds(items);
    if (adopted > 0) logger.info('Pull items: adopted $adopted');
    final res = await port.upsertRemote(items);
    await syncState.upsert(
      entityTable: port.entityTable,
      lastSyncAt: res.maxSyncAt ?? DateTime.now().toUtc(),
    );
    logger.info('Pull items: upserts=${res.upserts}');
    return res.upserts;
  }
}
