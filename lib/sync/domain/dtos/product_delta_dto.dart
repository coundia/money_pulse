/* DTO for Product delta push payload. */
class ProductDeltaDto {
  final String id;
  final String type;
  final String? remoteId;
  final String? code;
  final String? name;
  final String? description;
  final String? barcode;
  final String? unitId;
  final String? categoryId;
  final int defaultPrice;
  final int purchasePrice;
  final String? statuses;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int version;
  final String? syncAt;

  const ProductDeltaDto({
    required this.id,
    required this.type,
    this.remoteId,
    this.code,
    this.name,
    this.description,
    this.barcode,
    this.unitId,
    this.categoryId,
    required this.defaultPrice,
    required this.purchasePrice,
    this.statuses,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
    this.syncAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'remoteId': remoteId,
    'code': code,
    'name': name,
    'description': description,
    'barcode': barcode,
    'unitId': unitId,
    'categoryId': categoryId,
    'defaultPrice': defaultPrice,
    'purchasePrice': purchasePrice,
    'statuses': statuses,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'deletedAt': deletedAt,
    'version': version,
    'syncAt': syncAt,
  };
}
