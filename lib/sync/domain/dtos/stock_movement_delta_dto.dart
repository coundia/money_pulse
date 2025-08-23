/* DTO for StockMovement delta push payload. */
class StockMovementDeltaDto {
  final int? id;
  final String type;
  final String? typeStockMovement;
  final int quantity;
  final String? companyId;
  final String? productVariantId;
  final String? orderLineId;
  final String? discriminator;
  final String createdAt;
  final String updatedAt;
  final String? syncAt;

  const StockMovementDeltaDto({
    this.id,
    required this.type,
    this.typeStockMovement,
    required this.quantity,
    this.companyId,
    this.productVariantId,
    this.orderLineId,
    this.discriminator,
    required this.createdAt,
    required this.updatedAt,
    this.syncAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'type_stock_movement': typeStockMovement,
    'quantity': quantity,
    'companyId': companyId,
    'productVariantId': productVariantId,
    'orderLineId': orderLineId,
    'discriminator': discriminator,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'syncAt': syncAt,
  };
}
