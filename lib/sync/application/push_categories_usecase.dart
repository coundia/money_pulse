import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/outbox_pusher.dart';
import 'package:money_pulse/sync/application/push_port.dart';
import 'package:money_pulse/sync/domain/dtos/category_delta_dto.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';

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

  @override
  Future<int> execute({int batchSize = 200}) async {
    logger.info('Categories: drain change_log');
    final outbox = OutboxPusher(
      entityTable: 'category',
      changeLog: changeLog,
      syncState: syncState,
      logger: logger,
    );

    Future<Map<String, Object?>?> build(ChangeLogEntry e) async {
      final cat = await port.findById(e.entityId);
      if (cat == null) return null;
      final t = SyncDeltaTypeExt.fromOp(
        e.operation,
        deleted: cat.deletedAt != null,
      );
      final now = DateTime.now().toUtc();
      final dto = CategoryDeltaDto.fromEntity(cat, t, now).toJson();
      dto['localId'] = cat.id;
      dto['remoteId'] = cat.remoteId;
      return dto;
    }

    return outbox.push(
      buildPayload: build,
      postFn: (ds) => api.postCategoryDeltas(ds),
      markSyncedFn: port.markSynced,
      limit: batchSize,
    );
  }
}
