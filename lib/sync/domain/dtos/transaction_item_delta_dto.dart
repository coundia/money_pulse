// DTO for transaction item delta payloads.
import 'package:jaayko/sync/domain/sync_delta_type.dart';
import 'package:jaayko/sync/domain/sync_delta_type_ext.dart';

class TransactionItemDeltaDto {
  final String? id;
  final String localId;
  final String? remoteId;
  final String? transactionId;
  final String? productId;
  final String? label;
  final int? quantity;
  final String? unitId;
  final int? unitPrice;
  final int? total;
  final String? notes;
  final String? account;
  final String syncAt;
  final String operation;

  TransactionItemDeltaDto._({
    required this.id,
    required this.localId,
    required this.remoteId,
    required this.transactionId,
    required this.productId,
    required this.label,
    required this.account,
    required this.quantity,
    required this.unitId,
    required this.unitPrice,
    required this.total,
    required this.notes,
    required this.syncAt,
    required this.operation,
  });

  factory TransactionItemDeltaDto.fromEntity(
    dynamic it,
    SyncDeltaType t,
    DateTime now,
  ) {
    final isUpdateOrDelete = t != SyncDeltaType.create;
    final nowIso = (now.isUtc ? now : now.toUtc()).toIso8601String();
    final localId = (it.localId as String?) ?? (it.id as String);
    return TransactionItemDeltaDto._(
      id: isUpdateOrDelete ? it.remoteId as String? : null,
      localId: localId,
      account: it.account as String?,
      remoteId: it.remoteId as String?,
      transactionId: it.transactionId as String?,
      productId: it.productId as String?,
      label: it.label as String?,
      quantity: it.quantity as int?,
      unitId: it.unitId as String?,
      unitPrice: it.unitPrice as int?,
      total: it.total as int?,
      notes: it.notes as String?,
      syncAt: nowIso,
      operation: t.op,
    );
  }

  Map<String, Object?> toJson() => {
    'id': remoteId ?? id,
    'localId': localId,
    'remoteId': remoteId,
    'transaction': transactionId,
    'product': productId,
    'label': label,
    'account': account,
    'quantity': quantity,
    'unitId': unitId,
    'unitPrice': unitPrice,
    'total': total,
    'notes': notes,
    'syncAt': syncAt,
    'type': operation.toUpperCase(),
    'operation': operation,
  };
}
