// DTO for stock movement delta payloads.
import 'package:jaayko/sync/domain/sync_delta_type.dart';
import 'package:jaayko/sync/domain/sync_delta_type_ext.dart';

class StockMovementDeltaDto {
  final Object? id;
  final String localId;
  final String? remoteId;
  final String? typeStockMovement;
  final int? quantity;
  final String? companyId;
  final String? productVariantId;
  final String? orderLineId;
  final String? discriminator;
  final String? account;
  final String syncAt;
  final String operation;

  StockMovementDeltaDto._({
    required this.id,
    required this.localId,
    required this.remoteId,
    required this.typeStockMovement,
    required this.quantity,
    required this.account,
    required this.companyId,
    required this.productVariantId,
    required this.orderLineId,
    required this.discriminator,
    required this.syncAt,
    required this.operation,
  });

  factory StockMovementDeltaDto.fromEntity(
    dynamic m,
    SyncDeltaType t,
    DateTime now,
  ) {
    final isUpdateOrDelete = t != SyncDeltaType.create;
    final nowIso = (now.isUtc ? now : now.toUtc()).toIso8601String();
    final localId = (m.localId as String?) ?? (m.id.toString());
    return StockMovementDeltaDto._(
      id: isUpdateOrDelete ? m.remoteId : null,
      localId: localId,
      account: m.account as String?,
      remoteId: m.remoteId as String?,
      typeStockMovement: m.type as String?,
      quantity: m.quantity as int?,
      companyId: m.companyId as String?,
      productVariantId: m.productVariantId as String?,
      orderLineId: m.orderLineId as String?,
      discriminator: m.discriminator as String?,
      syncAt: nowIso,
      operation: t.op,
    );
  }

  Map<String, Object?> toJson() => {
    'id': remoteId ?? id,
    'localId': localId,
    'remoteId': remoteId,
    'typeStockMovement': typeStockMovement,
    'quantity': quantity,
    'account': account,
    'company': companyId,
    'productVariant': productVariantId,
    'orderLineId': orderLineId,
    'discriminator': discriminator,
    'syncAt': syncAt,

    'operation': operation,
    'type': operation.toLowerCase(),
  };
}
