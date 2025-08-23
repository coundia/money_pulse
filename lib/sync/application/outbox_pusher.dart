/* Robust outbox pusher: safely decodes payloads, skips/deletes invalid rows, posts valid deltas, updates sync_state and marks entities synced. */
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';

typedef Json = Map<String, Object?>;

class DeltaEnvelope {
  final String entityId;
  final String operation;
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
      if (v is Map<String, Object?>) return v;
      return null;
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
    if (envelopes.isNotEmpty) {
      await changeLog.enqueueAll(
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
    }

    final pending = await changeLog.findPendingByEntity(
      entityTable,
      limit: limit,
    );
    if (pending.isEmpty) return 0;

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
        'Outbox $entityTable: dropping ${invalidIds.length} invalid rows (null or bad JSON payload)',
      );
      for (final id in invalidIds) {
        await changeLog.delete(id);
      }
    }

    if (validDeltas.isEmpty) {
      logger.info('Outbox $entityTable: nothing valid to push after filtering');
      return 0;
    }

    final resp = await postFn(validDeltas);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = resp.body;
      final msg =
          'HTTP ${resp.statusCode} ${body.isEmpty ? '' : body.substring(0, body.length > 1000 ? 1000 : body.length)}';
      for (final p in validEntries) {
        await changeLog.markPending(p.id, error: msg);
      }
      throw StateError('Sync failed with status ${resp.statusCode}');
    }

    final now = DateTime.now();
    for (final p in validEntries) {
      await changeLog.markAck(p.id);
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
