// Drain-only outbox pusher: validates payloads, posts in batch, and marks each
// change_log row ACK/PENDING/FAILED with robust HTTP + partial-failure handling.
// + Logs détaillés sur toutes les erreurs.

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

  String _clip(String s, {int max = 512}) {
    if (s.length <= max) return s;
    return s.substring(0, max) + '…';
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

    // Compteur des raisons d’échec (diagnostic)
    final failReasons = <String, int>{};
    void _count(String reason) =>
        failReasons.update(reason, (v) => v + 1, ifAbsent: () => 1);

    for (final p in pending) {
      Json? payload;
      try {
        payload = await buildPayload(p);
      } catch (e, st) {
        logger.error(
          '[OutboxPusher.error] buildPayload exception for entity=${p.entityId} '
          'op=${p.operation}: $e\n$st',
        );
      }

      if (payload == null) {
        _count('payload_null');
        await changeLog.markFailed(p.id, error: 'Payload manquant/invalide');
        logger.warn(
          'Outbox $entityTable: payload invalide (entity=${p.entityId}, op=${p.operation})',
        );
        continue;
      }

      final opRaw = (p.operation ?? '').toUpperCase();

      payload['type'] ??= opRaw;

      final id = payload['id'];
      final remoteId = payload['remoteId'];

      // Logs de debug du payload
      logger.info(
        'Outbox $entityTable: validating entity=${p.entityId} '
        'op=$opRaw id=$id remoteId=$remoteId payload=${_clip(jsonEncode(payload))}',
      );

      if (opRaw == 'CREATE') {
        if (_isBlank(id)) {
          _count('create_sans_id');
          await changeLog.markFailed(p.id, error: 'CREATE sans id local');
          logger.warn(
            'Outbox $entityTable: reject CREATE (entity=${p.entityId}) car id local manquant',
          );
          continue;
        }
      } else if (opRaw == 'UPDATE') {
        if (_isBlank(remoteId)) {
          _count('update_sans_id');
          await changeLog.markFailed(p.id, error: 'UPDATE sans id local');
          logger.warn(
            'Outbox $entityTable: reject UPDATE (entity=${p.entityId}) car id local manquant',
          );
          continue;
        }
        if (_isBlank(remoteId)) {
          _count('update_sans_remoteId');
          await changeLog.markFailed(p.id, error: 'UPDATE sans remoteId');
          logger.warn(
            'Outbox $entityTable: reject UPDATE (entity=${p.entityId}) car remoteId manquant',
          );
          continue;
        }
      } else if (opRaw == 'DELETE') {
        if (_isBlank(remoteId)) {
          _count('delete_sans_remoteId');
          await changeLog.markFailed(p.id, error: 'DELETE sans remoteId');
          logger.warn(
            'Outbox $entityTable: reject DELETE (entity=${p.entityId}) car remoteId manquant',
          );
          continue;
        }
      }

      if (_isBlank(remoteId)) {
        payload['type'] = "CREATE";
      }

      validEntries.add(p);
      validDeltas.add(payload);
      await changeLog.markSent(p.id);
    }

    if (validDeltas.isEmpty) {
      if (failReasons.isEmpty) {
        logger.info('Outbox $entityTable: aucun delta valide à pousser');
      } else {
        final reasons = failReasons.entries
            .map((e) => '${e.key}=${e.value}')
            .join(', ');
        logger.info(
          'Outbox $entityTable: aucun delta valide à pousser (reasons: $reasons)',
        );
      }
      return 0;
    }

    http.Response resp;
    try {
      logger.info("******** POST DATA ****************************");
      logger.info(
        'Outbox $entityTable: POST count=${validDeltas.length} '
        'PAYLOAD=${_clip(jsonEncode(validDeltas))}',
      );
      resp = await postFn(validDeltas);
    } catch (e, st) {
      final msg = 'HTTP exception: $e';
      logger.error('[OutboxPusher.error] $msg\n$st');
      for (final p in validEntries) {
        await changeLog.markPending(p.id, error: msg);
      }
      return 0;
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = _clip(resp.body);
      final msg = 'HTTP ${resp.statusCode} $body';
      logger.error('[OutboxPusher.error] $msg');
      for (final p in validEntries) {
        await changeLog.markPending(p.id, error: msg);
      }
      return 0;
    }

    // Réponse OK => analyser
    final now = DateTime.now().toUtc();
    final parsed = _tryDecode(resp.body);

    if (parsed != null) {
      logger.info(
        'Outbox $entityTable: server response=${_clip(jsonEncode(parsed))}',
      );
    } else {
      logger.info(
        'Outbox $entityTable: server response (raw)=${_clip(resp.body)}',
      );
    }

    final entityIdToEntry = <String, ChangeLogEntry>{
      for (final e in validEntries) e.entityId: e,
    };

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
      logger.info(
        'Outbox $entityTable: no explicit ack/fail list ⇒ ACK all (${validEntries.length})',
      );
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

    if (ackEntityIds.isNotEmpty) {
      logger.info(
        'Outbox $entityTable: ack=${ackEntityIds.length} '
        'failed=${failedIds.length}',
      );
    } else {
      logger.warn('Outbox $entityTable: ack=0 failed=${failedIds.length}');
    }

    for (final id in ackEntityIds) {
      final p = entityIdToEntry[id];
      if (p != null) await changeLog.markAck(p.id);
    }
    for (final id in failedIds) {
      final p = entityIdToEntry[id];
      if (p != null) {
        await changeLog.markFailed(p.id, error: 'Échec serveur');
        logger.warn(
          'Outbox $entityTable: serveur a échoué pour entityId=$id (markFailed)',
        );
      }
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
