/* Robust outbox pusher: filters/cleans invalid pending rows, retries once, posts valid deltas, updates sync_state and marks entities synced only on 2xx. */
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
      return v is Map<String, Object?> ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<({List<ChangeLogEntry> entries, List<Json> deltas, bool dropped})>
  _loadFilterDrop(int limit, {bool dropInvalid = true}) async {
    final pending = await changeLog.findPendingByEntity(
      entityTable,
      limit: limit,
    );
    final validEntries = <ChangeLogEntry>[];
    final validDeltas = <Json>[];
    final invalidIds = <String>[];

    for (final p in pending) {
      final d = _tryDecode(p.payload);
      if (d == null) {
        invalidIds.add(p.id);
      } else {
        validEntries.add(p);
        validDeltas.add(d);
      }
    }

    if (dropInvalid && invalidIds.isNotEmpty) {
      logger.warn(
        'Outbox $entityTable: dropping ${invalidIds.length} invalid rows (null/bad JSON payload)',
      );
      for (final id in invalidIds) {
        await changeLog.delete(id);
      }
    }
    return (
      entries: validEntries,
      deltas: validDeltas,
      dropped: invalidIds.isNotEmpty,
    );
  }

  Future<int> push({
    required List<DeltaEnvelope> envelopes,
    required Future<http.Response> Function(List<Json> deltas) postFn,
    required Future<void> Function(Iterable<String> ids, DateTime at)
    markSyncedFn,
    int limit = 200,
  }) async {
    // 1) Enqueue new deltas (if any)
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

    // 2) Load + drop invalid once
    var filtered = await _loadFilterDrop(limit, dropInvalid: true);

    // 3) If all were invalid and got dropped (or they saturated the page), retry load once
    if (filtered.deltas.isEmpty && filtered.dropped) {
      filtered = await _loadFilterDrop(limit, dropInvalid: false);
      if (filtered.deltas.isEmpty) {
        logger.info(
          'Outbox $entityTable: nothing valid to push after cleaning',
        );
        return 0; // no sync state update, no markSynced (as demandé)
      }
    }

    if (filtered.deltas.isEmpty) {
      logger.info('Outbox $entityTable: nothing to push');
      return 0;
    }

    // 4) Post
    final resp = await postFn(filtered.deltas);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = resp.body;
      final msg =
          'HTTP ${resp.statusCode} ${body.isEmpty ? '' : (body.length > 1000 ? body.substring(0, 1000) : body)}';
      for (final p in filtered.entries) {
        await changeLog.markPending(p.id, error: msg);
      }
      throw StateError('Sync failed with status ${resp.statusCode}');
    }

    // 5) On success: ACK outbox, update sync_state, and mark entities as synced
    final now = DateTime.now();
    for (final p in filtered.entries) {
      await changeLog.markAck(p.id);
    }
    await syncState.upsert(
      entityTable: entityTable,
      lastSyncAt: now,
      lastCursor: null,
    );
    await markSyncedFn(filtered.entries.map((e) => e.entityId), now);
    logger.info('Outbox $entityTable pushed ${filtered.entries.length}');
    return filtered.entries.length;
  }
}
