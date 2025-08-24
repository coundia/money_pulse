/* Force-enqueue all local accounts as UPDATE: load existing change_log first, merge payloads, then push pending and ACK on success. */
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:money_pulse/sync/application/outbox_pusher.dart';
import 'package:money_pulse/sync/application/push_port.dart';
import 'package:money_pulse/sync/domain/dtos/account_delta_dto.dart';
import 'package:money_pulse/sync/domain/sync_delta_type.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import '_ports.dart';

typedef Json = Map<String, Object?>;

class PushAccountsForceUpdateUseCase implements PushPort {
  final Database db;
  final AccountSyncPort port;
  final ChangeLogRepository changeLog;
  final SyncStateRepository syncState;
  final SyncApiClient api;
  final SyncLogger logger;

  PushAccountsForceUpdateUseCase({
    required this.db,
    required this.port,
    required this.changeLog,
    required this.syncState,
    required this.api,
    required this.logger,
  });

  @override
  Future<int> execute({int batchSize = 1000}) async {
    logger.info('Accounts[forceUpdate]: read pending change_log…');
    final pendingIds = await changeLog.findPendingIdsByEntity('account');
    logger.info('Accounts[forceUpdate]: pending count=${pendingIds.length}');

    final rows = await db.query(
      'account',
      where: 'deletedAt IS NULL',
      orderBy: 'updatedAt DESC',
      limit: batchSize,
    );
    if (rows.isEmpty) {
      logger.info('Accounts[forceUpdate]: no local accounts found');
      return 0;
    }

    final now = DateTime.now();
    final toUpsert = <({String entityId, String operation, String payload})>[];

    for (final m in rows) {
      final acc = Account.fromMap(m);
      final dto = AccountDeltaDto.fromEntity(
        acc,
        SyncDeltaType.update,
        now,
      ).toJson();
      toUpsert.add((
        entityId: acc.id,
        operation: SyncDeltaType.update.op,
        payload: jsonEncode(dto),
      ));
    }

    logger.info(
      'Accounts[forceUpdate]: enqueueOrMergeAll for ${toUpsert.length} UPDATE ops',
    );
    await changeLog.enqueueOrMergeAll('account', toUpsert);

    final outbox = OutboxPusher(
      entityTable: 'account',
      changeLog: changeLog,
      syncState: syncState,
      logger: logger,
    );

    logger.info('Accounts[forceUpdate]: push PENDING now');
    final pushed = await outbox.push(
      envelopes: const [],
      postFn: (ds) => api.postAccountDeltas(ds),
      markSyncedFn: port.markSynced,
      limit: batchSize,
    );

    logger.info('Accounts[forceUpdate]: pushed=$pushed');
    return pushed;
  }
}
