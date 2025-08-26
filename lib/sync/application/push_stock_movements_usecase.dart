// Push use case for stock movements using change_log outbox.
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/push_port.dart';
import 'package:money_pulse/sync/domain/dtos/stock_movement_delta_dto.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';
import 'outbox_pusher.dart';

class PushStockMovementsUseCase implements PushPort {
  final StockMovementSyncPort port;
  final SyncApiClient api;
  final ChangeLogRepository changeLog;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PushStockMovementsUseCase({
    required this.port,
    required this.api,
    required this.changeLog,
    required this.syncState,
    required this.logger,
  });

  @override
  Future<int> execute({int batchSize = 200}) async {
    final outbox = OutboxPusher(
      entityTable: 'stock_movement',
      changeLog: changeLog,
      syncState: syncState,
      logger: logger,
    );

    Future<Map<String, Object?>?> build(ChangeLogEntry e) async {
      final entity = await port.findById(e.entityId);
      if (entity == null) return null;
      final t = SyncDeltaTypeExt.fromOp(e.operation);
      final dto = StockMovementDeltaDto.fromEntity(
        entity,
        t,
        DateTime.now().toUtc(),
      ).toJson();
      dto['localId'] = entity.id.toString();
      dto['remoteId'] = entity.remoteId;
      return dto;
    }

    return outbox.push(
      buildPayload: build,
      postFn: (ds) => api.postStockMovementDeltas(ds),
      markSyncedFn: port.markSynced,
      limit: batchSize,
    );
  }
}
