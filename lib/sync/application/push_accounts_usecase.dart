// lib/sync/application/push_accounts_usecase.dart
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/outbox_pusher.dart';
import 'package:money_pulse/sync/application/push_port.dart';
import 'package:money_pulse/sync/domain/dtos/account_delta_dto.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';

class PushAccountsUseCase implements PushPort {
  final AccountSyncPort port;
  final SyncApiClient api;
  final ChangeLogRepository changeLog;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PushAccountsUseCase({
    required this.port,
    required this.api,
    required this.changeLog,
    required this.syncState,
    required this.logger,
  });

  @override
  Future<int> execute({int batchSize = 200}) async {
    logger.info('Accounts: drain change_log');
    final outbox = OutboxPusher(
      entityTable: 'account',
      changeLog: changeLog,
      syncState: syncState,
      logger: logger,
    );

    Future<Map<String, Object?>?> build(ChangeLogEntry e) async {
      final acc = await port.findById(e.entityId);
      if (acc == null) return null;
      final t = SyncDeltaTypeExt.fromOp(
        e.operation,
        deleted: acc.deletedAt != null,
      );
      final now = DateTime.now().toUtc();
      final dto = AccountDeltaDto.fromEntity(acc, t, now).toJson();
      // si tu veux toujours envoyer localId :
      dto['localId'] = acc.id;
      dto['remoteId'] = acc.remoteId;
      return dto;
    }

    return outbox.push(
      buildPayload: build,
      postFn: (ds) => api.postAccountDeltas(ds),
      markSyncedFn: port.markSynced,
      limit: batchSize,
    );
  }
}
