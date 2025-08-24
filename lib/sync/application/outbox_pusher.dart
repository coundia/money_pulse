import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';

typedef Json = Map<String, Object?>;

class DeltaEnvelope {
  final String entityId; // local id
  final String operation; // CREATE|UPDATE|DELETE
  final Json delta;
  DeltaEnvelope({
    required this.entityId,
    required this.operation,
    required this.delta,
  });
}

class OutboxPusher {
  final String entityTable;
  final ChangeLogRepository changeLog;
  final SyncStateRepository syncState;
  final SyncLogger logger;

  OutboxPusher({
    required this.entityTable,
    required this.changeLog,
    required this.syncState,
    required this.logger,
  });

  Json? _tryDecode(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final v = jsonDecode(s);
      return v is Map<String, Object?> ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<int> push({
    required List<DeltaEnvelope> envelopes,
    required Future<http.Response> Function(List<Json> deltas) postFn,
    required Future<void> Function(Iterable<String> ids, DateTime at)
    markSyncedFn,
    int limit = 200,
  }) async {
    // 1) Enqueue newly built envelopes
    if (envelopes.isNotEmpty) {
      await changeLog.enqueueOrMergeAll(
        entityTable,
        envelopes
            .map(
              (e) => (
                entityId: e.entityId,
                operation: e.operation,
                payload: jsonEncode(e.delta),
              ),
            )
            .toList(),
      );
      logger.info('Outbox $entityTable: enqueueOrMergeAll=${envelopes.length}');
    } else {
      logger.info('Outbox $entityTable: no new envelopes to enqueue');
    }

    // 2) Load PENDING
    final pending = await changeLog.findPendingByEntity(
      entityTable,
      limit: limit,
    );
    logger.info('Outbox $entityTable: pending=${pending.length}');
    if (pending.isEmpty) return 0;

    // 3) Filter invalid payloads
    final validEntries = <ChangeLogEntry>[];
    final validDeltas = <Json>[];
    final invalidIds = <String>[];

    for (final p in pending) {
      final decoded = _tryDecode(p.payload);
      if (decoded == null) {
        invalidIds.add(p.id);
      } else {
        validEntries.add(p);
        validDeltas.add(decoded);
      }
    }

    if (invalidIds.isNotEmpty) {
      logger.warn(
        'Outbox $entityTable: dropping ${invalidIds.length} invalid rows (null/bad JSON payload)',
      );
      for (final id in invalidIds) {
        await changeLog.delete(id);
      }
    }

    if (validDeltas.isEmpty) {
      logger.info('Outbox $entityTable: nothing valid to push after cleaning');
      return 0;
    }

    // 4) POST
    logger.info('Outbox $entityTable: POST count=${validDeltas.length}');
    final resp = await postFn(validDeltas);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = resp.body;
      final msg =
          'HTTP ${resp.statusCode} ${body.isEmpty ? '' : body.substring(0, body.length > 512 ? 512 : body.length)}';
      for (final p in validEntries) {
        await changeLog.markPending(p.id, error: msg);
      }
      throw StateError('Sync failed with status ${resp.statusCode}');
    }

    // 5) ACK
    final now = DateTime.now().toUtc();
    for (final p in validEntries) {
      await changeLog.markSent(p.id);
    }

    await syncState.upsert(
      entityTable: entityTable,
      lastSyncAt: now,
      lastCursor: null,
    );
    await markSyncedFn(validEntries.map((e) => e.entityId), now);
    logger.info('Outbox $entityTable pushed ${validEntries.length}');
    return validEntries.length;
  }
}
