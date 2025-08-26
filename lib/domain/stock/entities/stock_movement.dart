/// Domain entity representing a stock movement audit row.
class StockMovement {
  final int? id;
  final String type; // 'IN','OUT','ALLOCATE','RELEASE','ADJUST'
  final int quantity;
  final String companyId;
  final String productVariantId;
  final String? orderLineId;
  final String? discriminator;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? localId;
  final String? remoteId;

  const StockMovement({
    this.id,
    required this.type,
    required this.quantity,
    required this.companyId,
    required this.productVariantId,
    this.orderLineId,
    this.discriminator,
    this.remoteId,
    this.localId,
    required this.createdAt,
    required this.updatedAt,
  });

  StockMovement copyWith({
    int? id,
    String? type,
    int? quantity,
    String? companyId,
    String? productVariantId,
    String? orderLineId,
    String? discriminator,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StockMovement(
      id: id ?? this.id,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      companyId: companyId ?? this.companyId,
      productVariantId: productVariantId ?? this.productVariantId,
      orderLineId: orderLineId ?? this.orderLineId,
      discriminator: discriminator ?? this.discriminator,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory StockMovement.fromMap(Map<String, Object?> m) {
    return StockMovement(
      id: m['id'] as int?,
      type: (m['type_stock_movement'] as String),
      quantity: (m['quantity'] as int?) ?? 0,
      companyId: (m['companyId'] as String),
      productVariantId: (m['productVariantId'] as String),
      orderLineId: m['orderLineId'] as String?,
      discriminator: m['discriminator'] as String?,
      createdAt:
          DateTime.tryParse((m['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((m['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type_stock_movement': type,
      'quantity': quantity,
      'companyId': companyId,
      'productVariantId': productVariantId,
      'orderLineId': orderLineId,
      'discriminator': discriminator,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
