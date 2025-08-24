/* Standard account push: build deltas for dirty accounts, merge into change_log first, then push pending. */
import 'dart:convert';
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
    final items = await port.findDirty(limit: batchSize);
    if (items.isEmpty) {
      logger.info('Accounts: nothing dirty');
      return 0;
    }

    final now = DateTime.now();
    final pendingTriples = items.map((a) {
      final t = a.deletedAt != null
          ? SyncDeltaType.delete
          : (a.remoteId == null ? SyncDeltaType.create : SyncDeltaType.update);
      final dto = AccountDeltaDto.fromEntity(a, t, now).toJson();
      return (entityId: a.id, operation: t.op, payload: jsonEncode(dto));
    }).toList();

    logger.info('Accounts: enqueueOrMergeAll=${pendingTriples.length}');
    await changeLog.enqueueOrMergeAll('account', pendingTriples);

    final outbox = OutboxPusher(
      entityTable: 'account',
      changeLog: changeLog,
      syncState: syncState,
      logger: logger,
    );

    logger.info('Accounts: push PENDING');
    final pushed = await outbox.push(
      envelopes: const [],
      postFn: (ds) => api.postAccountDeltas(ds),
      markSyncedFn: port.markSynced,
      limit: batchSize,
    );

    logger.info('Accounts: pushed=$pushed');
    return pushed;
  }
}
