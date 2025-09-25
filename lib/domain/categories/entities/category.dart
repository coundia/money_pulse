class Category {
  final String id;
  final String? localId;
  final String? remoteId;
  final String code;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final int version;
  final bool isDirty;
  final String typeEntry;
  final String? account;
  final String? status;
  final bool isPublic;

  static const String debit = 'DEBIT';
  static const String credit = 'CREDIT';

  const Category({
    required this.id,
    this.localId,
    this.remoteId,
    required this.code,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.account,
    this.version = 0,
    this.isDirty = true,
    this.typeEntry = debit,
    this.status,
    this.isPublic = true,
  }) : assert(
         typeEntry == debit || typeEntry == credit,
         "typeEntry must be either 'DEBIT' or 'CREDIT'",
       );

  bool get isDeleted => deletedAt != null;
  bool get isDebit => typeEntry == debit;
  bool get isCredit => typeEntry == credit;
  int get sign => isDebit ? -1 : 1;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    final s = v.toString().trim();
    if (!s.contains('T') && s.contains(' ')) {
      return DateTime.tryParse(s.replaceFirst(' ', 'T'));
    }
    return DateTime.tryParse(s);
  }

  static bool _parseDirty(dynamic v) {
    if (v == null) return true;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 't' || s == 'yes' || s == 'y';
  }

  static bool _parseBool(dynamic v, {required bool defaultValue}) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 't' || s == 'yes' || s == 'y';
  }

  static String _normType(dynamic v) {
    final s = (v ?? debit).toString().toUpperCase().trim();
    if (s == credit) return credit;
    return debit;
  }

  factory Category.fromMap(Map<String, Object?> m) {
    final id = m['id'] as String;
    return Category(
      id: id,
      localId: (m['localId'] as String?) ?? id,
      remoteId: m['remoteId'] as String?,
      code: m['code'] as String,
      account: m['account'] as String?,
      description: m['description'] as String?,
      createdAt: _parseDate(m['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(m['updatedAt']) ?? DateTime.now(),
      deletedAt: _parseDate(m['deletedAt']),
      syncAt: _parseDate(m['syncAt']),
      version: (m['version'] as int?) ?? 0,
      isDirty: _parseDirty(m['isDirty']),
      typeEntry: _normType(m['typeEntry']),
      status: m['status'] as String?,
      isPublic: _parseBool(m['isPublic'], defaultValue: true),
    );
  }

  Map<String, Object?> toMap() {
    String? f(DateTime? d) => d?.toIso8601String();
    return {
      'id': id,
      'localId': localId,
      'remoteId': remoteId,
      'code': code,
      'account': account,
      'description': description,
      'createdAt': f(createdAt),
      'updatedAt': f(updatedAt),
      'deletedAt': f(deletedAt),
      'syncAt': f(syncAt),
      'version': version,
      'isDirty': isDirty ? 1 : 0,
      'typeEntry': typeEntry.toUpperCase(),
      'status': status,
      'isPublic': isPublic ? 1 : 0,
    };
  }

  factory Category.fromJson(Map<String, Object?> json) =>
      Category.fromMap(json);
  Map<String, Object?> toJson() => toMap();

  Category copyWith({
    String? id,
    String? localId,
    String? remoteId,
    String? code,
    String? account,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    int? version,
    bool? isDirty,
    String? typeEntry,
    String? status,
    bool? isPublic,
  }) {
    final te = typeEntry ?? this.typeEntry;
    assert(
      te == debit || te == credit,
      "typeEntry must be 'DEBIT' or 'CREDIT'",
    );
    return Category(
      id: id ?? this.id,
      localId: localId ?? this.localId,
      remoteId: remoteId ?? this.remoteId,
      code: code ?? this.code,
      account: account ?? this.account,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
      typeEntry: te,
      status: status ?? this.status,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.localId == localId &&
        other.remoteId == remoteId &&
        other.code == code &&
        other.description == description &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.deletedAt == deletedAt &&
        other.account == account &&
        other.syncAt == syncAt &&
        other.version == version &&
        other.isDirty == isDirty &&
        other.typeEntry == typeEntry &&
        other.status == status &&
        other.isPublic == isPublic;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      (localId?.hashCode ?? 0) ^
      (remoteId?.hashCode ?? 0) ^
      code.hashCode ^
      (description?.hashCode ?? 0) ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      (deletedAt?.hashCode ?? 0) ^
      (syncAt?.hashCode ?? 0) ^
      version.hashCode ^
      isDirty.hashCode ^
      typeEntry.hashCode ^
      (status?.hashCode ?? 0) ^
      isPublic.hashCode;

  @override
  String toString() =>
      'Category(id: $id, localId: $localId, code: $code, typeEntry: $typeEntry, status: $status, isPublic: $isPublic, version: $version, isDirty: $isDirty)';
}
