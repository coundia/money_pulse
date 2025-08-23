/* DTO for StockLevel delta push payload. */
class StockLevelDeltaDto {
  final int? id;
  final String type;
  final int stockOnHand;
  final int stockAllocated;
  final String? productVariantId;
  final String? companyId;
  final String createdAt;
  final String updatedAt;
  final String? syncAt;

  const StockLevelDeltaDto({
    this.id,
    required this.type,
    required this.stockOnHand,
    required this.stockAllocated,
    this.productVariantId,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
    this.syncAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'stockOnHand': stockOnHand,
    'stockAllocated': stockAllocated,
    'productVariantId': productVariantId,
    'companyId': companyId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'syncAt': syncAt,
  };
}
