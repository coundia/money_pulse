// Helper to upsert change_log row with optional account/createdBy.
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

Future<void> upsertChangeLogPending(
  DatabaseExecutor exec, {
  required String entityTable,
  required String entityId,
  required String operation,
  Object? payload,
  DateTime? at,
  String? logId,
  String status = 'PENDING',
  String? accountId,
  String? createdBy,
}) async {
  final idLog = logId ?? const Uuid().v4();
  final nowIso = (at ?? DateTime.now().toUtc()).toIso8601String();

  final String? payloadStr = switch (payload) {
    null => null,
    String s => s,
    _ => jsonEncode(payload),
  };

  await exec.rawInsert(
    '''
    INSERT INTO change_log(
      id, entityTable, entityId, operation, payload, status, createdAt, updatedAt, account, createdBy
    )
    VALUES(?,?,?,?,?,?,?,?,?,?)
    ON CONFLICT(entityTable, entityId, status) DO UPDATE SET
      operation=excluded.operation,
      updatedAt=excluded.updatedAt,
      payload=excluded.payload,
      account=COALESCE(excluded.account, change_log.account),
      createdBy=COALESCE(excluded.createdBy, change_log.createdBy)
    ''',
    [
      idLog,
      entityTable,
      entityId,
      operation,
      payloadStr,
      status,
      nowIso,
      nowIso,
      accountId,
      createdBy,
    ],
  );
}
