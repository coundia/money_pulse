// lib/sync/application/outbox_pusher.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';

typedef Json = Map<String, Object?>;

/// Mode drain-only : ne fait AUCUN enqueue.
/// Lit `change_log` (PENDING), construit le payload si nécessaire via [buildPayload],
/// POST puis marque chaque ligne en SYNC et met à jour sync_state + markSyncedFn.
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
    required Future<http.Response> Function(List<Json> deltas) postFn,
    required Future<void> Function(Iterable<String> ids, DateTime at)
    markSyncedFn,
    required Future<Json?> Function(ChangeLogEntry entry) buildPayload,
    int limit = 200,
  }) async {
    // 1) Charger les PENDING
    final pending = await changeLog.findPendingByEntity(
      entityTable,
      limit: limit,
    );
    logger.info('Outbox $entityTable: pending=${pending.length}');
    if (pending.isEmpty) return 0;

    // 2) Construire/valider les payloads
    final validEntries = <ChangeLogEntry>[];
    final validDeltas = <Json>[];

    for (final p in pending) {
      final decoded = await buildPayload(p);
      if (decoded == null) {
        await changeLog.markFailed(p.id, error: 'Missing/invalid payload');
        continue;
      }

      decoded["type"] = decoded["operation"];

      if (decoded["remoteId"] == null || decoded["id"] == null) {
        decoded["type"] = "CREATE";
      }

      validEntries.add(p);
      validDeltas.add(decoded);
    }

    if (validDeltas.isEmpty) {
      logger.info(
        'Outbox $entityTable: nothing valid to push after building payloads',
      );
      return 0;
    }

    // 3) POST

    print("***** POST ****");
    print(validDeltas);

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

    //sent
    final now = DateTime.now().toUtc();
    for (final p in validEntries) {
      await changeLog.markAck(p.id);
    }

    await syncState.upsert(
      entityTable: entityTable,
      lastSyncAt: now,
      lastCursor: null,
    );
    await markSyncedFn(validEntries.map((e) => e.entityId), now);

    logger.info('Outbox $entityTable: synced ${validEntries.length}');

    return validEntries.length;
  }
}
