// Inserts a PENDING change_log row; always inserts and surfaces SQLite errors without upsert.
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

Future<void> upsertChangeLogPending(
  DatabaseExecutor exec, {
  required String entityTable,
  required String entityId,
  required String operation,
  Map<String, dynamic>? payload,
  DateTime? at,
  String? logId,
  String status = 'PENDING',
  String? accountId,
  String? createdBy,
}) async {
  final idLog = logId ?? const Uuid().v4();
  final nowIso = (at ?? DateTime.now().toUtc()).toIso8601String();
  final String? payloadStr = payload == null ? null : jsonEncode(payload);

  final row = <String, Object?>{
    'id': idLog,
    'entityTable': entityTable,
    'entityId': entityId,
    'operation': operation,
    'payload': payloadStr,
    'status': status,
    'createdAt': nowIso,
    'updatedAt': nowIso,
    'account': accountId,
    'createdBy': createdBy,
  };

  try {
    await exec.insert(
      'change_log',
      row,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  } on DatabaseException catch (e) {
    print(' ❌  change_log insert failed for $entityTable/$entityId: $e');
  }
}
