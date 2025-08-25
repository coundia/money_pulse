import 'package:money_pulse/infrastructure/db/app_database.dart';
import 'package:money_pulse/sync/application/_ports.dart';
import 'package:money_pulse/sync/application/outbox_pusher.dart';
import 'package:money_pulse/sync/application/push_port.dart';
import 'package:money_pulse/sync/domain/dtos/transaction_delta_dto.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';
import 'package:money_pulse/sync/infrastructure/sync_api_client.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';
import 'package:sqflite/sqlite_api.dart';

import '../infrastructure/remote_id_lookup.dart';
import '_pull_ports.dart';

class PushTransactionsUseCase implements PushPort {
  final TransactionSyncPort port;
  final SyncApiClient api;
  final ChangeLogRepository changeLog;
  final SyncStateRepository syncState;
  final SyncLogger logger;
  final Database db;

  PushTransactionsUseCase(
    this.port,
    this.api,
    this.changeLog,
    this.syncState,
    this.logger,
    this.db,
  );

  @override
  Future<int> execute({int batchSize = 200}) async {
    logger.info('Transactions: drain change_log');
    final outbox = OutboxPusher(
      entityTable: 'transaction_entry',
      changeLog: changeLog,
      syncState: syncState,
      logger: logger,
    );

    Future<Map<String, Object?>?> build(ChangeLogEntry e) async {
      final tx = await port.findById(e.entityId);
      if (tx == null) return null;
      final t = SyncDeltaTypeExt.fromOp(
        e.operation,
        deleted: tx.deletedAt != null,
      );
      final now = DateTime.now().toUtc();
      final dto = TransactionDeltaDto.fromEntity(tx, t, now);
      final dtoJson = dto.toJson();

      dtoJson['localId'] = tx.id;
      dtoJson['remoteId'] = tx.remoteId;

      print(dto.account);

      dtoJson['account'] = await remoteIdOfDb(db, 'account', dto.account);
      dtoJson['category'] = await remoteIdOfDb(db, 'category', dto.category);
      dtoJson['customer'] = await remoteIdOfDb(db, 'customer', dto.customer);
      dtoJson['company'] = await remoteIdOfDb(db, 'company', dto.company);

      return dtoJson;
    }

    return outbox.push(
      buildPayload: build,
      postFn: (ds) => api.postTransactionDeltas(ds),
      markSyncedFn: port.markSynced,
      limit: batchSize,
    );
  }
}
