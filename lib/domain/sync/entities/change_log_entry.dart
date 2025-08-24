/* Pure Dart entity (no Flutter import required). */
import 'package:money_pulse/sync/domain/sync_delta_type.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';

class ChangeLogEntry {
  final String id;
  final String entityTable; //account, category etc.
  final String entityId;
  final String? operation; // 'CREATE' | 'UPDATE' | 'DELETE'
  final String? payload; // JSON or any serialized text
  final String? status; // 'PENDING' | 'SENT' | 'ACK' | 'FAILED'
  final int attempts;
  final String? error;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? processedAt;

  const ChangeLogEntry({
    required this.id,
    required this.entityTable,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.error,
    required this.createdAt,
    required this.updatedAt,
    required this.processedAt,
  });

  // Convenience: typed access to operation as SyncDeltaType
  SyncDeltaType? get opType => SyncDeltaTypeExt.fromOp(operation);

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: false);
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final iso = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(iso);
  }

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final p = int.tryParse(v.toString());
    return p ?? fallback;
  }

  factory ChangeLogEntry.fromMap(Map<String, Object?> m) {
    return ChangeLogEntry(
      id: m['id'] as String,
      entityTable: m['entityTable'] as String,
      entityId: m['entityId'] as String,
      operation: m['operation'] as String?,
      payload: m['payload'] as String?,
      status: m['status'] as String?,
      attempts: _toInt(m['attempts']),
      error: m['error'] as String?,
      createdAt: _parseDate(m['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(m['updatedAt']) ?? DateTime.now(),
      processedAt: _parseDate(m['processedAt']),
    );
  }

  Map<String, Object?> toMap() {
    String? _fmt(DateTime? dt) => dt?.toIso8601String();
    return {
      'id': id,
      'entityTable': entityTable,
      'entityId': entityId,
      'operation': operation,
      'payload': payload,
      'status': status,
      'attempts': attempts,
      'error': error,
      'createdAt': _fmt(createdAt),
      'updatedAt': _fmt(updatedAt),
      'processedAt': _fmt(processedAt),
    };
  }

  ChangeLogEntry copyWith({
    String? id,
    String? entityTable,
    String? entityId,
    String? operation,
    String? payload,
    String? status,
    int? attempts,
    String? error,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? processedAt,
  }) {
    return ChangeLogEntry(
      id: id ?? this.id,
      entityTable: entityTable ?? this.entityTable,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }

  @override
  String toString() =>
      'ChangeLogEntry(id=$id, table=$entityTable, entityId=$entityId, op=$operation, status=$status, attempts=$attempts)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChangeLogEntry &&
        other.id == id &&
        other.entityTable == entityTable &&
        other.entityId == entityId &&
        other.operation == operation &&
        other.payload == payload &&
        other.status == status &&
        other.attempts == attempts &&
        other.error == error &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.processedAt == processedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityTable,
    entityId,
    operation,
    payload,
    status,
    attempts,
    error,
    createdAt,
    updatedAt,
    processedAt,
  );
}
