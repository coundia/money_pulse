class StockLevel {
  final String? id;
  final String productVariantId;
  final String companyId;
  final int stockOnHand;
  final int stockAllocated;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncAt;
  final int version;
  final bool isDirty;
  final String? localId;
  final String? remoteId;

  StockLevel({
    this.id,
    required this.productVariantId,
    required this.companyId,
    required this.stockOnHand,
    required this.stockAllocated,
    required this.createdAt,
    required this.updatedAt,
    this.syncAt,
    this.remoteId,
    this.localId,
    this.version = 0,
    this.isDirty = true,
  });

  StockLevel copyWith({
    String? id,
    String? productVariantId,
    String? companyId,
    int? stockOnHand,
    int? stockAllocated,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncAt,
    int? version,
    bool? isDirty,
  }) {
    return StockLevel(
      id: id ?? this.id,
      productVariantId: productVariantId ?? this.productVariantId,
      companyId: companyId ?? this.companyId,
      stockOnHand: stockOnHand ?? this.stockOnHand,
      stockAllocated: stockAllocated ?? this.stockAllocated,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  factory StockLevel.fromMap(Map<String, Object?> map) {
    DateTime? _parse(Object? v) {
      if (v == null) return null;
      final s = v.toString();
      return DateTime.tryParse(s.contains('T') ? s : s.replaceFirst(' ', 'T'));
    }

    return StockLevel(
      id: (map['id'] as String?) ?? map['id']?.toString() ?? '',
      productVariantId: map['productVariantId'] as String? ?? '',
      companyId: map['companyId'] as String? ?? '',
      stockOnHand: (map['stockOnHand'] as int?) ?? 0,
      stockAllocated: (map['stockAllocated'] as int?) ?? 0,
      createdAt: _parse(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parse(map['updatedAt']) ?? DateTime.now(),
      syncAt: _parse(map['syncAt']),
      version: (map['version'] as int?) ?? 0,
      isDirty: ((map['isDirty'] as int?) ?? 1) == 1,
    );
  }

  Map<String, Object?> toMap() {
    String? _fmt(DateTime? d) => d?.toIso8601String();
    return {
      'id': id,
      'productVariantId': productVariantId,
      'companyId': companyId,
      'stockOnHand': stockOnHand,
      'stockAllocated': stockAllocated,
      'createdAt': _fmt(createdAt),
      'updatedAt': _fmt(updatedAt),
      'syncAt': _fmt(syncAt),
      'version': version,
      'isDirty': isDirty ? 1 : 0,
    };
  }
}
