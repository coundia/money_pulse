class Category {
  final String id;
  final String? remoteId;
  final String code;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final int version;
  final bool isDirty;

  const Category({
    required this.id,
    this.remoteId,
    required this.code,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.version = 0,
    this.isDirty = true,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    final s = v.toString();
    if (s.contains('T')) return DateTime.parse(s);
    return DateTime.parse(s.replaceFirst(' ', 'T'));
  }

  factory Category.fromMap(Map<String, Object?> m) {
    return Category(
      id: m['id'] as String,
      remoteId: m['remoteId'] as String?,
      code: m['code'] as String,
      description: m['description'] as String?,
      createdAt: _parseDate(m['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(m['updatedAt']) ?? DateTime.now(),
      deletedAt: _parseDate(m['deletedAt']),
      syncAt: _parseDate(m['syncAt']),
      version: (m['version'] as int?) ?? 0,
      isDirty: ((m['isDirty'] as int?) ?? 1) == 1,
    );
  }

  Map<String, Object?> toMap() {
    String? f(DateTime? d) => d?.toIso8601String();
    return {
      'id': id,
      'remoteId': remoteId,
      'code': code,
      'description': description,
      'createdAt': f(createdAt),
      'updatedAt': f(updatedAt),
      'deletedAt': f(deletedAt),
      'syncAt': f(syncAt),
      'version': version,
      'isDirty': isDirty ? 1 : 0,
    };
  }

  Category copyWith({
    String? id,
    String? remoteId,
    String? code,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    int? version,
    bool? isDirty,
  }) {
    return Category(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      code: code ?? this.code,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}
