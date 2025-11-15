// Push use case for account_users using change_log outbox.
import 'package:jaayko/sync/application/_ports.dart';
import 'package:jaayko/sync/application/push_port.dart';
import 'package:jaayko/sync/domain/dtos/account_user_delta_dto.dart';
import 'package:jaayko/sync/domain/sync_delta_type_ext.dart';
import 'package:jaayko/sync/infrastructure/sync_api_client.dart';
import 'package:jaayko/domain/sync/repositories/change_log_repository.dart';
import 'package:jaayko/domain/sync/repositories/sync_state_repository.dart';
import 'package:jaayko/sync/infrastructure/sync_logger.dart';
import 'package:jaayko/domain/sync/entities/change_log_entry.dart';
import 'outbox_pusher.dart';

class PushAccountUsersUseCase implements PushPort {
  final AccountUserSyncPort port;
  final SyncApiClient api;
  final ChangeLogRepository changeLog;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PushAccountUsersUseCase({
    required this.port,
    required this.api,
    required this.changeLog,
    required this.syncState,
    required this.logger,
  });

  @override
  Future<int> execute({int batchSize = 200}) async {
    final outbox = OutboxPusher(
      entityTable: 'account_users',
      changeLog: changeLog,
      syncState: syncState,
      logger: logger,
    );

    Future<Map<String, Object?>?> build(ChangeLogEntry e) async {
      final entity = await port.findById(e.entityId);

      final t = SyncDeltaTypeExt.fromOp(e.operation);

      if (entity == null) return null;

      final dto = AccountUserDeltaDto.fromEntity(
        entity,
        t,
        DateTime.now().toUtc(),
      ).toJson();
      dto['localId'] = entity.id;
      dto['remoteId'] = entity.remoteId;
      return dto;
    }

    return outbox.push(
      buildPayload: build,
      postFn: (ds) => api.postAccountUserDeltas(ds),
      markSyncedFn: port.markSynced,
      limit: batchSize,
    );
  }
}
