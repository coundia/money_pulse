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
  final String? account;
  final String? company;
  final String? levelId;
  final int quantity;
  final int hasSold;
  final int hasPrice;
  final int defaultPrice;
  final int purchasePrice;
  final String? statuses;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final String? createdBy;
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
    this.account,
    this.company,
    this.levelId,
    this.quantity = 0,
    this.hasSold = 0,
    this.hasPrice = 0,
    this.defaultPrice = 0,
    this.purchasePrice = 0,
    this.statuses,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.createdBy,
    this.version = 0,
    this.isDirty = 1,
  });

  Product copyWith({
    String? id,
    String? remoteId,
    String? localId,
    String? code,
    String? name,
    String? description,
    String? barcode,
    String? unitId,
    String? categoryId,
    String? account,
    String? company,
    String? levelId,
    int? quantity,
    int? hasSold,
    int? hasPrice,
    int? defaultPrice,
    int? purchasePrice,
    String? statuses,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    String? createdBy,
    int? version,
    int? isDirty,
  }) {
    return Product(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      localId: localId ?? this.localId,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      barcode: barcode ?? this.barcode,
      unitId: unitId ?? this.unitId,
      categoryId: categoryId ?? this.categoryId,
      account: account ?? this.account,
      company: company ?? this.company,
      levelId: levelId ?? this.levelId,
      quantity: quantity ?? this.quantity,
      hasSold: hasSold ?? this.hasSold,
      hasPrice: hasPrice ?? this.hasPrice,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      statuses: statuses ?? this.statuses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      createdBy: createdBy ?? this.createdBy,
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
    localId: m['localId'] as String?,
    code: m['code'] as String?,
    name: m['name'] as String?,
    description: m['description'] as String?,
    barcode: m['barcode'] as String?,
    unitId: m['unitId'] as String?,
    categoryId: m['categoryId'] as String?,
    account: m['account'] as String?,
    company: m['company'] as String?,
    levelId: m['levelId'] as String?,
    quantity: (m['quantity'] as num?)?.toInt() ?? 0,
    hasSold: (m['hasSold'] as num?)?.toInt() ?? 0,
    hasPrice: (m['hasPrice'] as num?)?.toInt() ?? 0,
    defaultPrice: (m['defaultPrice'] as num?)?.toInt() ?? 0,
    purchasePrice: (m['purchasePrice'] as num?)?.toInt() ?? 0,
    statuses: m['statuses'] as String?,
    createdAt: _dt(m['createdAt']) ?? DateTime.now(),
    updatedAt: _dt(m['updatedAt']) ?? DateTime.now(),
    deletedAt: _dt(m['deletedAt']),
    syncAt: _dt(m['syncAt']),
    createdBy: m['createdBy'] as String?,
    version: (m['version'] as num?)?.toInt() ?? 0,
    isDirty: (m['isDirty'] as num?)?.toInt() ?? 1,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'remoteId': remoteId,
    'localId': localId,
    'code': code,
    'name': name,
    'description': description,
    'barcode': barcode,
    'unitId': unitId,
    'categoryId': categoryId,
    'account': account,
    'company': company,
    'levelId': levelId,
    'quantity': quantity,
    'hasSold': hasSold,
    'hasPrice': hasPrice,
    'defaultPrice': defaultPrice,
    'purchasePrice': purchasePrice,
    'statuses': statuses,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    'syncAt': syncAt?.toIso8601String(),
    'createdBy': createdBy,
    'version': version,
    'isDirty': isDirty,
  };
}
