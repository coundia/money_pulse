import 'package:money_pulse/infrastructure/repositories/sync_state_repository_sqflite.dart';
import 'package:money_pulse/infrastructure/sync/change_log_sqlite_repository.dart';
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/outbox_pusher.dart';
import 'package:money_pulse/sync/application/push_port.dart';
import 'package:money_pulse/sync/domain/dtos/account_delta_dto.dart';
import 'package:money_pulse/sync/domain/sync_delta_type.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';
import 'package:money_pulse/sync/infrastructure/sqflite_sync_ports.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:sqflite_common/sqlite_api.dart';

class PushAccountsUseCase implements PushPort {
  final AccountSyncPort port;
  final SyncApiClient api;
  final ChangeLogRepository changeLog;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  PushAccountsUseCase(
    this.port,
    this.api,
    this.changeLog,
    this.syncState,
    this.logger,
  );

  @override
  Future<int> execute({int batchSize = 200}) async {
    logger.info('Accounts: building envelopes');
    final now = DateTime.now().toUtc();
    final items = await port.findDirty(limit: batchSize);

    final envelopes = items.map((a) {
      final SyncDeltaType type;
      if (a.remoteId == null) {
        type = SyncDeltaType.create;
      } else {
        type = SyncDeltaType.update;
      }
      final dto = AccountDeltaDto.fromEntity(a, type, now).toJson();
      return DeltaEnvelope(entityId: a.id, operation: type.op, delta: dto);
    }).toList();

    final outbox = OutboxPusher(
      entityTable: 'account',
      changeLog: changeLog,
      syncState: syncState,
      logger: logger,
    );

    return outbox.push(
      envelopes: envelopes,
      postFn: (ds) => api.postAccountDeltas(ds),
      markSyncedFn: port.markSynced,
      limit: batchSize,
    );
  }
}
