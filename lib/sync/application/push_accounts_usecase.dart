// push_accounts_usecase.dart
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/outbox_pusher.dart';
import 'package:money_pulse/sync/application/push_port.dart';
import 'package:money_pulse/sync/domain/dtos/account_delta_dto.dart';
import 'package:money_pulse/sync/domain/sync_delta_type.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:sqflite/sqflite.dart' show Database;

class PushAccountsUseCase implements PushPort {
  final AccountSyncPort port;
  final SyncApiClient api;
  final ChangeLogRepository changeLog;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  // Only needed if you plan to run raw SQL; otherwise you can drop it.
  final Database? db;

  const PushAccountsUseCase({
    required this.port,
    required this.api,
    required this.changeLog,
    required this.syncState,
    required this.logger,
    this.db,
  });

  @override
  Future<int> execute({int batchSize = 200}) async {
    logger.info('Accounts: building envelopes');
    final now = DateTime.now().toUtc();

    final items = await port.findDirty(limit: batchSize);
    if (items.isEmpty) {
      logger.info('Accounts: nothing to push');
      return 0;
    }

    final envelopes = items.map((a) {
      final type = (a.deletedAt != null)
          ? SyncDeltaType.delete
          : (a.remoteId == null ? SyncDeltaType.create : SyncDeltaType.update);

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
