/* Pushes categories using outbox pusher with change_log and sync_state. */
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/outbox_pusher.dart';
import 'package:money_pulse/sync/domain/dtos/category_delta_dto.dart';
import 'package:money_pulse/sync/domain/sync_delta_type.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';

import 'push_port.dart';

class PushCategoriesUseCase implements PushPort {
  final CategorySyncPort port;
  final SyncApiClient api;
  final ChangeLogRepository changeLog;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PushCategoriesUseCase(
    this.port,
    this.api,
    this.changeLog,
    this.syncState,
    this.logger,
  );

  Future<int> execute({int batchSize = 200}) async {
    final items = await port.findDirty(limit: batchSize);
    final now = DateTime.now();
    final envelopes = items.map((c) {
      final type = c.deletedAt != null
          ? SyncDeltaType.delete
          : SyncDeltaType.update;
      final dto = CategoryDeltaDto.fromEntity(c, type, now).toJson();
      return DeltaEnvelope(
        entityId: c.id,
        operation: type.name.toUpperCase(),
        delta: dto,
      );
    }).toList();

    final outbox = OutboxPusher(
      entityTable: 'category',
      changeLog: changeLog,
      syncState: syncState,
      logger: logger,
    );

    return outbox.push(
      envelopes: envelopes,
      postFn: (ds) => api.postCategoryDeltas(ds),
      markSyncedFn: port.markSynced,
      limit: batchSize,
    );
  }
}
