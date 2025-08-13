/// StockLevel entity storing per-product per-company stock figures.
class StockLevel {
  final int? id;
  final String productVariantId;
  final String companyId;
  final int stockOnHand;
  final int stockAllocated;
  final DateTime createdAt;
  final DateTime updatedAt;

  StockLevel({
    this.id,
    required this.productVariantId,
    required this.companyId,
    required this.stockOnHand,
    required this.stockAllocated,
    required this.createdAt,
    required this.updatedAt,
  });

  StockLevel copyWith({
    int? id,
    String? productVariantId,
    String? companyId,
    int? stockOnHand,
    int? stockAllocated,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StockLevel(
      id: id ?? this.id,
      productVariantId: productVariantId ?? this.productVariantId,
      companyId: companyId ?? this.companyId,
      stockOnHand: stockOnHand ?? this.stockOnHand,
      stockAllocated: stockAllocated ?? this.stockAllocated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
