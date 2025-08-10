class TransactionEntry {
  final String id;
  final String? remoteId;
  final String? code;
  final String? description;
  final int amount;
  final String typeEntry;
  final DateTime dateTransaction;
  final String? status;
  final String? entityName;
  final String? entityId;
  final String accountId;
  final String? categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final int version;
  final bool isDirty;

  const TransactionEntry({
    required this.id,
    this.remoteId,
    this.code,
    this.description,
    required this.amount,
    required this.typeEntry,
    required this.dateTransaction,
    this.status,
    this.entityName,
    this.entityId,
    required this.accountId,
    this.categoryId,
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

  factory TransactionEntry.fromMap(Map<String, Object?> m) {
    return TransactionEntry(
      id: m['id'] as String,
      remoteId: m['remoteId'] as String?,
      code: m['code'] as String?,
      description: m['description'] as String?,
      amount: (m['amount'] as int?) ?? 0,
      typeEntry: m['typeEntry'] as String,
      dateTransaction: _parseDate(m['dateTransaction']) ?? DateTime.now(),
      status: m['status'] as String?,
      entityName: m['entityName'] as String?,
      entityId: m['entityId'] as String?,
      accountId: m['accountId'] as String,
      categoryId: m['categoryId'] as String?,
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
      'amount': amount,
      'typeEntry': typeEntry,
      'dateTransaction': f(dateTransaction),
      'status': status,
      'entityName': entityName,
      'entityId': entityId,
      'accountId': accountId,
      'categoryId': categoryId,
      'createdAt': f(createdAt),
      'updatedAt': f(updatedAt),
      'deletedAt': f(deletedAt),
      'syncAt': f(syncAt),
      'version': version,
      'isDirty': isDirty ? 1 : 0,
    };
  }

  TransactionEntry copyWith({
    String? id,
    String? remoteId,
    String? code,
    String? description,
    int? amount,
    String? typeEntry,
    DateTime? dateTransaction,
    String? status,
    String? entityName,
    String? entityId,
    String? accountId,
    String? categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    int? version,
    bool? isDirty,
  }) {
    return TransactionEntry(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      code: code ?? this.code,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      typeEntry: typeEntry ?? this.typeEntry,
      dateTransaction: dateTransaction ?? this.dateTransaction,
      status: status ?? this.status,
      entityName: entityName ?? this.entityName,
      entityId: entityId ?? this.entityId,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}
