// DTO for debt delta payloads.
import 'package:money_pulse/sync/domain/sync_delta_type.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';

class DebtDeltaDto {
  final String? id;
  final String localId;
  final String? remoteId;
  final String? code;
  final String? notes;
  final int? balance;
  final int? balanceDebt;
  final String? dueDate;
  final String? statuses;
  final String? customerId;
  final String syncAt;
  final String operation;

  DebtDeltaDto._({
    required this.id,
    required this.localId,
    required this.remoteId,
    required this.code,
    required this.notes,
    required this.balance,
    required this.balanceDebt,
    required this.dueDate,
    required this.statuses,
    required this.customerId,
    required this.syncAt,
    required this.operation,
  });

  factory DebtDeltaDto.fromEntity(dynamic d, SyncDeltaType t, DateTime now) {
    final isUpdateOrDelete = t != SyncDeltaType.create;
    final nowIso = (now.isUtc ? now : now.toUtc()).toIso8601String();
    final localId = (d.localId as String?) ?? (d.id as String);
    return DebtDeltaDto._(
      id: isUpdateOrDelete ? d.remoteId as String? : null,
      localId: localId,
      remoteId: d.remoteId as String?,
      code: d.code as String?,
      notes: d.notes as String?,
      balance: d.balance as int?,
      balanceDebt: d.balanceDebt as int?,
      dueDate: d.dueDate?.toString(),
      statuses: d.statuses as String?,
      customerId: d.customerId as String?,
      syncAt: nowIso,
      operation: t.op,
    );
  }

  Map<String, Object?> toJson() => {
    if (id != null) 'id': id,
    'localId': localId,
    'remoteId': remoteId,
    'code': code,
    'notes': notes,
    'balance': balance,
    'balanceDebt': balanceDebt,
    'dueDate': dueDate,
    'statuses': statuses,
    'customerId': customerId,
    'syncAt': syncAt,
    'operation': operation,
  };
}
