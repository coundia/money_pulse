// Helper to insert PENDING change_log rows with safe de-duplication by UUID.
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

Future<bool> _existsPendingById(DatabaseExecutor exec, String entityId) async {
  final rows = await exec.rawQuery(
    'SELECT 1 FROM change_log WHERE entityId=? AND status=? LIMIT 1',
    [entityId, 'PENDING'],
  );
  return rows.isNotEmpty;
}

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
  print("## upsertChangeLogPending ###");

  final idLog = logId ?? const Uuid().v4();
  if (status == 'PENDING' && await _existsPendingById(exec, entityId)) {
    print("## _existsPendingById ###");
    return;
  }

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
    // Optionally ignore duplicates if they slipped past the check:
    final isConstraint = e.isUniqueConstraintError();
    if (isConstraint &&
        status == 'PENDING' &&
        await _existsPendingById(exec, idLog)) {
      return;
    }
    rethrow;
  }
}
