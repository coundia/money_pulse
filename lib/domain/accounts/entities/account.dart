// Entity for accounts with init/goal/limit balances, date range and type.
class Account {
  final String id; // local PK in your SQLite
  final String? localId; // explicit client-side id sent to server
  final String? remoteId; // server id (nullable until created remotely)

  final int balance;
  final int balancePrev;
  final int balanceBlocked;
  final int balanceInit;
  final int balanceGoal;
  final int balanceLimit;

  final String? code;
  final String? description;
  final String? status;
  final String? currency;
  final String? typeAccount;
  final DateTime? dateStartAccount;
  final DateTime? dateEndAccount;
  final bool isDefault;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final int version;
  final bool isDirty;

  const Account({
    required this.id,
    this.localId,
    this.remoteId,
    this.balance = 0,
    this.balancePrev = 0,
    this.balanceBlocked = 0,
    this.balanceInit = 0,
    this.balanceGoal = 0,
    this.balanceLimit = 0,
    this.code,
    this.description,
    this.status,
    this.currency,
    this.typeAccount,
    this.dateStartAccount,
    this.dateEndAccount,
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
    String? localId,
    String? remoteId,
    int? balance,
    int? balancePrev,
    int? balanceBlocked,
    int? balanceInit,
    int? balanceGoal,
    int? balanceLimit,
    String? code,
    String? description,
    String? status,
    String? currency,
    String? typeAccount,
    DateTime? dateStartAccount,
    DateTime? dateEndAccount,
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
      localId: localId ?? this.localId,
      remoteId: remoteId ?? this.remoteId,
      balance: balance ?? this.balance,
      balancePrev: balancePrev ?? this.balancePrev,
      balanceBlocked: balanceBlocked ?? this.balanceBlocked,
      balanceInit: balanceInit ?? this.balanceInit,
      balanceGoal: balanceGoal ?? this.balanceGoal,
      balanceLimit: balanceLimit ?? this.balanceLimit,
      code: code ?? this.code,
      description: description ?? this.description,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      typeAccount: typeAccount ?? this.typeAccount,
      dateStartAccount: dateStartAccount ?? this.dateStartAccount,
      dateEndAccount: dateEndAccount ?? this.dateEndAccount,
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
    if (s.contains('T')) return DateTime.tryParse(s);
    return DateTime.tryParse(s.replaceFirst(' ', 'T'));
  }

  factory Account.fromMap(Map<String, Object?> map) {
    final id = map['id'] as String;
    final localId = (map['localId'] as String?) ?? id; // fallback for old rows
    return Account(
      id: id,
      localId: localId,
      remoteId: map['remoteId'] as String?,
      balance: (map['balance'] as int?) ?? 0,
      balancePrev: (map['balance_prev'] as int?) ?? 0,
      balanceBlocked: (map['balance_blocked'] as int?) ?? 0,
      balanceInit: (map['balance_init'] as int?) ?? 0,
      balanceGoal: (map['balance_goal'] as int?) ?? 0,
      balanceLimit: (map['balance_limit'] as int?) ?? 0,
      code: map['code'] as String?,
      description: map['description'] as String?,
      status: map['status'] as String?,
      currency: map['currency'] as String?,
      typeAccount: map['typeAccount'] as String?,
      dateStartAccount: _parseDate(map['dateStartAccount']),
      dateEndAccount: _parseDate(map['dateEndAccount']),
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
      'localId': localId,
      'remoteId': remoteId,
      'balance': balance,
      'balance_prev': balancePrev,
      'balance_blocked': balanceBlocked,
      'balance_init': balanceInit,
      'balance_goal': balanceGoal,
      'balance_limit': balanceLimit,
      'code': code,
      'description': description,
      'status': status,
      'currency': currency,
      'typeAccount': typeAccount,
      'dateStartAccount': _fmt(dateStartAccount),
      'dateEndAccount': _fmt(dateEndAccount),
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
