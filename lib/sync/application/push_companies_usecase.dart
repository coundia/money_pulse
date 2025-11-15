/* Push use case for companies: drains change_log via OutboxPusher and posts deltas to API. */
import 'package:jaayko/sync/application/_ports.dart';
import 'package:jaayko/sync/application/outbox_pusher.dart';
import 'package:jaayko/sync/application/push_port.dart';
import 'package:jaayko/sync/domain/dtos/company_delta_dto.dart';
import 'package:jaayko/sync/domain/sync_delta_type_ext.dart';
import 'package:jaayko/sync/infrastructure/sync_api_client.dart';
import 'package:jaayko/domain/sync/repositories/change_log_repository.dart';
import 'package:jaayko/domain/sync/repositories/sync_state_repository.dart';
import 'package:jaayko/sync/infrastructure/sync_logger.dart';
import 'package:jaayko/domain/sync/entities/change_log_entry.dart';

class PushCompaniesUseCase implements PushPort {
  final CompanySyncPort port;
  final SyncApiClient api;
  final ChangeLogRepository changeLog;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PushCompaniesUseCase(
    this.port,
    this.api,
    this.changeLog,
    this.syncState,
    this.logger,
  );

  @override
  Future<int> execute({int batchSize = 200}) async {
    logger.info('Companies: drain change_log');
    final outbox = OutboxPusher(
      entityTable: 'company',
      changeLog: changeLog,
      syncState: syncState,
      logger: logger,
    );

    Future<Map<String, Object?>?> build(ChangeLogEntry e) async {
      final c = await port.findById(e.entityId);
      if (c == null) return null;
      final t = SyncDeltaTypeExt.fromOp(
        e.operation,
        deleted: c.deletedAt != null,
      );
      final now = DateTime.now().toUtc();
      final dto = CompanyDeltaDto.fromEntity(c, t, now).toJson();
      dto['localId'] = c.id;
      dto['remoteId'] = c.remoteId;
      return dto;
    }

    return outbox.push(
      buildPayload: build,
      postFn: (ds) => api.postCompanyDeltas(ds),
      markSyncedFn: port.markSynced,
      limit: batchSize,
    );
  }
}
