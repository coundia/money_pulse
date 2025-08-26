// Push use case for transaction items using change_log outbox.
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/push_port.dart';
import 'package:money_pulse/sync/domain/dtos/transaction_item_delta_dto.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';
import 'outbox_pusher.dart';

class PushTransactionItemsUseCase implements PushPort {
  final TransactionItemSyncPort port;
  final SyncApiClient api;
  final ChangeLogRepository changeLog;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PushTransactionItemsUseCase({
    required this.port,
    required this.api,
    required this.changeLog,
    required this.syncState,
    required this.logger,
  });

  @override
  Future<int> execute({int batchSize = 200}) async {
    final outbox = OutboxPusher(
      entityTable: 'transaction_item',
      changeLog: changeLog,
      syncState: syncState,
      logger: logger,
    );

    Future<Map<String, Object?>?> build(entity) async {
      final e = await port.findById(entity.entityId);
      if (e == null) return null;
      final t = SyncDeltaTypeExt.fromOp(
        entity.operation,
        deleted: e.deletedAt != null,
      );
      final dto = TransactionItemDeltaDto.fromEntity(
        e,
        t,
        DateTime.now().toUtc(),
      ).toJson();
      dto['localId'] = e.id;
      dto['remoteId'] = e.remoteId;
      return dto;
    }

    return outbox.push(
      buildPayload: (x) => build(x),
      postFn: (ds) => api.postTransactionItemDeltas(ds),
      markSyncedFn: port.markSynced,
      limit: batchSize,
    );
  }
}
