class Product {
  final String id;
  final String? remoteId;
  final String? localId;
  final String? code;
  final String? name;
  final String? description;
  final String? barcode;
  final String? unitId;
  final String? categoryId;
  final int defaultPrice; // cents (prix de vente)
  final int purchasePrice;
  final String? statuses;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final int version;
  final int isDirty;

  const Product({
    required this.id,
    this.remoteId,
    this.localId,
    this.code,
    this.name,
    this.description,
    this.barcode,
    this.unitId,
    this.categoryId,
    this.defaultPrice = 0,
    this.purchasePrice =
        0, // default; repo will fallback to defaultPrice if needed
    this.statuses,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.version = 0,
    this.isDirty = 1,
  });

  Product copyWith({
    String? id,
    String? remoteId,
    String? code,
    String? name,
    String? description,
    String? barcode,
    String? unitId,
    String? categoryId,
    int? defaultPrice,
    int? purchasePrice,
    String? statuses,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    int? version,
    int? isDirty,
  }) {
    return Product(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      barcode: barcode ?? this.barcode,
      unitId: unitId ?? this.unitId,
      categoryId: categoryId ?? this.categoryId,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      statuses: statuses ?? this.statuses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString();
    return DateTime.tryParse(s.contains('T') ? s : s.replaceFirst(' ', 'T'));
  }

  factory Product.fromMap(Map<String, Object?> m) => Product(
    id: m['id'] as String,
    remoteId: m['remoteId'] as String?,
    code: m['code'] as String?,
    name: m['name'] as String?,
    description: m['description'] as String?,
    barcode: m['barcode'] as String?,
    unitId: m['unitId'] as String?,
    categoryId: m['categoryId'] as String?,
    defaultPrice: (m['defaultPrice'] as num?)?.toInt() ?? 0,
    purchasePrice: (m['purchasePrice'] as num?)?.toInt() ?? 0,
    statuses: m['statuses'] as String?,
    createdAt: _dt(m['createdAt']) ?? DateTime.now(),
    updatedAt: _dt(m['updatedAt']) ?? DateTime.now(),
    deletedAt: _dt(m['deletedAt']),
    syncAt: _dt(m['syncAt']),
    version: (m['version'] as num?)?.toInt() ?? 0,
    isDirty: (m['isDirty'] as num?)?.toInt() ?? 1,
  );

  Map<String, Object?> toMap() => {
    'id': id,
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
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    'syncAt': syncAt?.toIso8601String(),
    'version': version,
    'isDirty': isDirty,
  };
}
