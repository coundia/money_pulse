// Drain-only outbox pusher: validates payloads, posts in batch, and marks each change_log row ACK/PENDING/FAILED with robust HTTP + partial-failure handling.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:money_pulse/domain/sync/entities/change_log_entry.dart';
import 'package:money_pulse/domain/sync/repositories/change_log_repository.dart';
import 'package:money_pulse/domain/sync/repositories/sync_state_repository.dart';
import 'package:money_pulse/sync/infrastructure/sync_logger.dart';

typedef Json = Map<String, Object?>;

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

  Map<String, Object?>? _tryDecode(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final v = jsonDecode(s);
      return v is Map<String, Object?> ? v : null;
    } catch (_) {
      return null;
    }
  }

  bool _isBlank(Object? v) => v == null || (v is String && v.trim().isEmpty);

  Set<String> _extractIdSet(Object? raw) {
    final out = <String>{};
    void addOne(Object? x) {
      if (x is String && x.trim().isNotEmpty) out.add(x);
      if (x is Map) {
        final c = x['id'] ?? x['entityId'] ?? x['localId'];
        if (c is String && c.trim().isNotEmpty) out.add(c);
      }
    }

    if (raw is List) {
      for (final e in raw) addOne(e);
    } else {
      addOne(raw);
    }
    return out;
  }

  Future<int> push({
    required Future<http.Response> Function(List<Json> deltas) postFn,
    required Future<void> Function(Iterable<String> ids, DateTime at)
    markSyncedFn,
    required Future<Json?> Function(ChangeLogEntry entry) buildPayload,
    int limit = 200,
  }) async {
    final pending = await changeLog.findPendingByEntity(
      entityTable,
      limit: limit,
    );
    logger.info('Outbox $entityTable: pending=${pending.length}');
    if (pending.isEmpty) return 0;

    final validEntries = <ChangeLogEntry>[];
    final validDeltas = <Json>[];

    for (final p in pending) {
      final payload = await buildPayload(p);
      if (payload == null) {
        await changeLog.markFailed(p.id, error: 'Payload manquant/invalide');
        continue;
      }

      final op = (p.operation ?? '').toUpperCase();
      payload['type'] ??= op;

      final id = payload['id'];
      final remoteId = payload['remoteId'];

      if (op == 'CREATE') {
        if (_isBlank(id)) {
          await changeLog.markFailed(p.id, error: 'CREATE sans id local');
          continue;
        }
      } else if (op == 'UPDATE') {
        if (_isBlank(id)) {
          await changeLog.markFailed(p.id, error: 'UPDATE sans id local');
          continue;
        }
        if (_isBlank(remoteId)) {
          await changeLog.markFailed(p.id, error: 'UPDATE sans remoteId');
          continue;
        }
      } else if (op == 'DELETE') {
        if (_isBlank(remoteId)) {
          await changeLog.markFailed(p.id, error: 'DELETE sans remoteId');
          continue;
        }
      } else {
        await changeLog.markFailed(p.id, error: 'Opération inconnue: $op');
        continue;
      }

      validEntries.add(p);
      validDeltas.add(payload);
    }

    if (validDeltas.isEmpty) {
      logger.info('Outbox $entityTable: aucun delta valide à pousser');
      return 0;
    }

    http.Response resp;
    try {
      logger.info('Outbox $entityTable: POST count=${validDeltas.length}');
      resp = await postFn(validDeltas);
    } catch (e) {
      final msg = 'HTTP exception: $e';
      logger.error('[OutboxPusher.error] $msg');
      for (final p in validEntries) {
        await changeLog.markPending(p.id, error: msg);
      }
      return 0;
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = resp.body;
      final clipped = body.isEmpty
          ? ''
          : body.substring(0, body.length > 512 ? 512 : body.length);
      final msg = 'HTTP ${resp.statusCode} $clipped';
      logger.error('[OutboxPusher.error] $msg');
      for (final p in validEntries) {
        await changeLog.markPending(p.id, error: msg);
      }
      return 0;
    }

    final now = DateTime.now().toUtc();

    final entityIdToEntry = <String, ChangeLogEntry>{
      for (final e in validEntries) e.entityId: e,
    };

    final parsed = _tryDecode(resp.body);

    final failedIds = <String>{
      if (parsed != null)
        ..._extractIdSet(
          parsed['failed'] ?? parsed['failedIds'] ?? parsed['errors'] ?? [],
        ),
    };

    final ackEntityIds = <String>{
      for (final d in validDeltas)
        if (d['id'] is String && !failedIds.contains(d['id']))
          d['id'] as String,
    };

    if (failedIds.isEmpty && ackEntityIds.isEmpty) {
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

    for (final id in ackEntityIds) {
      final p = entityIdToEntry[id];
      if (p != null) await changeLog.markAck(p.id);
    }
    for (final id in failedIds) {
      final p = entityIdToEntry[id];
      if (p != null) await changeLog.markFailed(p.id, error: 'Échec serveur');
    }

    if (ackEntityIds.isNotEmpty) {
      await syncState.upsert(
        entityTable: entityTable,
        lastSyncAt: now,
        lastCursor: null,
      );
      await markSyncedFn(ackEntityIds, now);
    }

    logger.info(
      'Outbox $entityTable: ack=${ackEntityIds.length} failed=${failedIds.length}',
    );
    return ackEntityIds.length;
  }
}
