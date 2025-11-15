// DTO for stock level delta payloads.
import 'package:jaayko/sync/domain/sync_delta_type.dart';
import 'package:jaayko/sync/domain/sync_delta_type_ext.dart';

class StockLevelDeltaDto {
  final Object? id;
  final String localId;
  final String? remoteId;
  final String? productVariantId;
  final String? companyId;
  final int? stockOnHand;
  final int? stockAllocated;
  final String? account;
  final String syncAt;
  final String operation;

  StockLevelDeltaDto._({
    required this.id,
    required this.account,
    required this.localId,
    required this.remoteId,
    required this.productVariantId,
    required this.companyId,
    required this.stockOnHand,
    required this.stockAllocated,
    required this.syncAt,
    required this.operation,
  });

  factory StockLevelDeltaDto.fromEntity(
    dynamic s,
    SyncDeltaType t,
    DateTime now,
  ) {
    final isUpdateOrDelete = t != SyncDeltaType.create;
    final nowIso = (now.isUtc ? now : now.toUtc()).toIso8601String();
    final localId = (s.localId as String?) ?? (s.id.toString());
    return StockLevelDeltaDto._(
      id: isUpdateOrDelete ? s.remoteId : null,
      localId: localId,
      account: s.account as String?,
      remoteId: s.remoteId as String?,
      productVariantId: s.productVariantId as String?,
      companyId: s.companyId as String?,
      stockOnHand: s.stockOnHand as int?,
      stockAllocated: s.stockAllocated as int?,
      syncAt: nowIso,
      operation: t.op,
    );
  }

  Map<String, Object?> toJson() => {
    'id': remoteId ?? id,
    'localId': localId,
    'remoteId': remoteId,
    'productVariant': productVariantId,
    'company': companyId,
    'account': account,
    'stockOnHand': stockOnHand,
    'stockAllocated': stockAllocated,
    'syncAt': syncAt,
    'operation': operation,
    'type': operation.toUpperCase(),
  };
}
