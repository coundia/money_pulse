/* Robust outbox pusher:
 * - Safely decodes payloads
 * - Falls back to ChangeLogEntry.operation to ensure 'type' in delta JSON
 * - Skips/deletes invalid rows
 * - Posts valid deltas, updates sync_state and marks entities synced
 */
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';
import 'package:money_pulse/sync/domain/sync_delta_type.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';

typedef Json = Map<String, Object?>;

class DeltaEnvelope {
  final String entityId;
  final String operation; // CREATE / UPDATE / DELETE
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
    // 1) Enqueue new envelopes (operation stored in change_log.operation)
    if (envelopes.isNotEmpty) {
      await changeLog.enqueueAll(
        entityTable,
        envelopes
            .map(
              (e) => (
                entityId: e.entityId,
                operation: e.operation, // already uppercase (enum.op)
                payload: jsonEncode(e.delta),
              ),
            )
            .toList(),
      );
    }

    // 2) Load pending
    final pending = await changeLog.findPendingByEntity(
      entityTable,
      limit: limit,
    );
    if (pending.isEmpty) return 0;

    // 3) Validate/prepare deltas
    final validEntries = <ChangeLogEntry>[];
    final validDeltas = <Json>[];
    final invalidIds = <String>[];

    for (final p in pending) {
      final decoded = _tryDecode(p.payload);
      if (decoded == null) {
        invalidIds.add(p.id);
        continue;
      }

      // Ensure 'type' field in payload matches operation if missing
      // (we do NOT override an existing 'type')
      if (!decoded.containsKey('type')) {
        final opT = p.opType; // from ChangeLogEntry.operation → SyncDeltaType?
        if (opT != null) {
          decoded['type'] = opT.op; // CREATE / UPDATE / DELETE
        }
      }

      // Minimal sanity check: type must be valid if present
      final t = decoded['type']?.toString().toUpperCase();
      if (t != null && SyncDeltaTypeExt.fromOp(t) == null) {
        // invalid type → drop row
        invalidIds.add(p.id);
        continue;
      }

      validEntries.add(p);
      validDeltas.add(decoded);
    }

    // 4) Drop invalid rows
    if (invalidIds.isNotEmpty) {
      logger.warn(
        'Outbox $entityTable: dropping ${invalidIds.length} invalid rows (null/bad JSON payload or bad type)',
      );
      for (final id in invalidIds) {
        await changeLog.delete(id);
      }
    }

    if (validDeltas.isEmpty) {
      logger.info('Outbox $entityTable: nothing valid to push after cleaning');
      return 0;
    }

    // 5) POST
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

    // 6) Mark ACK + sync_state + markSynced
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
