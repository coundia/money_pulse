/* DTO for TransactionItem delta push payload. */
class TransactionItemDeltaDto {
  final String id;
  final String type;
  final String transactionId;
  final String? productId;
  final String? label;
  final int quantity;
  final String? unitId;
  final int unitPrice;
  final int total;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int version;
  final String? syncAt;

  const TransactionItemDeltaDto({
    required this.id,
    required this.type,
    required this.transactionId,
    this.productId,
    this.label,
    required this.quantity,
    this.unitId,
    required this.unitPrice,
    required this.total,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
    this.syncAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'transactionId': transactionId,
    'productId': productId,
    'label': label,
    'quantity': quantity,
    'unitId': unitId,
    'unitPrice': unitPrice,
    'total': total,
    'notes': notes,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'deletedAt': deletedAt,
    'version': version,
    'syncAt': syncAt,
  };
}
