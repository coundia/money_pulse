class Account {
  final String id;
  final String? remoteId;
  final int balance;
  final int balancePrev;
  final int balanceBlocked;
  final String? code;
  final String? description;
  final String? status;
  final String? currency;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final int version;
  final bool isDirty;

  const Account({
    required this.id,
    this.remoteId,
    this.balance = 0,
    this.balancePrev = 0,
    this.balanceBlocked = 0,
    this.code,
    this.description,
    this.status,
    this.currency,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.version = 0,
    this.isDirty = true,
  });

  Account copyWith({
    String? id,
    String? remoteId,
    int? balance,
    int? balancePrev,
    int? balanceBlocked,
    String? code,
    String? description,
    String? status,
    String? currency,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    int? version,
    bool? isDirty,
  }) {
    return Account(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      balance: balance ?? this.balance,
      balancePrev: balancePrev ?? this.balancePrev,
      balanceBlocked: balanceBlocked ?? this.balanceBlocked,
      code: code ?? this.code,
      description: description ?? this.description,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    final s = v.toString();
    if (s.contains('T')) return DateTime.parse(s);
    return DateTime.parse(s.replaceFirst(' ', 'T'));
  }

  factory Account.fromMap(Map<String, Object?> map) {
    return Account(
      id: map['id'] as String,
      remoteId: map['remoteId'] as String?,
      balance: (map['balance'] as int?) ?? 0,
      balancePrev: (map['balance_prev'] as int?) ?? 0,
      balanceBlocked: (map['balance_blocked'] as int?) ?? 0,
      code: map['code'] as String?,
      description: map['description'] as String?,
      status: map['status'] as String?,
      currency: map['currency'] as String?,
      isDefault: ((map['isDefault'] as int?) ?? 0) == 1,
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(map['updatedAt']) ?? DateTime.now(),
      deletedAt: _parseDate(map['deletedAt']),
      syncAt: _parseDate(map['syncAt']),
      version: (map['version'] as int?) ?? 0,
      isDirty: ((map['isDirty'] as int?) ?? 1) == 1,
    );
  }

  Map<String, Object?> toMap() {
    String? _fmt(DateTime? d) => d?.toIso8601String();
    return {
      'id': id,
      'remoteId': remoteId,
      'balance': balance,
      'balance_prev': balancePrev,
      'balance_blocked': balanceBlocked,
      'code': code,
      'description': description,
      'status': status,
      'currency': currency,
      'isDefault': isDefault ? 1 : 0,
      'createdAt': _fmt(createdAt),
      'updatedAt': _fmt(updatedAt),
      'deletedAt': _fmt(deletedAt),
      'syncAt': _fmt(syncAt),
      'version': version,
      'isDirty': isDirty ? 1 : 0,
    };
  }
}
