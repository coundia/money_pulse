// lib/domain/transactions/entities/transaction_entry.dart

class TransactionEntry {
  final String id;
  final String? remoteId;
  final String? code;
  final String? description;
  final int amount;
  final String
  typeEntry; // 'DEBIT' | 'CREDIT' | 'DEBT' | 'REMBOURSEMENT' | 'PRET' ...
  final DateTime dateTransaction;
  final String? status;
  final String? entityName;
  final String? entityId;
  final String? accountId; // <-- nullable
  final String? categoryId;

  final String? companyId;
  final String? customerId;

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
    this.accountId, // <-- nullable
    this.categoryId,
    this.companyId,
    this.customerId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.version = 0,
    this.isDirty = true,
  });

  // ------------------------ Helpers ------------------------

  static String? _asString(Object? v) => v?.toString();

  static int _asInt(Object? v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static bool _asBool(Object? v, {bool fallback = true}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    if (s == '1' || s == 'true') return true;
    if (s == '0' || s == 'false') return false;
    return fallback;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    final s = v.toString();
    if (s.isEmpty) return null;
    // Autoriser les formats "YYYY-MM-DD HH:MM:SS" en remplaçant l'espace par 'T'
    final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    try {
      return DateTime.parse(normalized);
    } catch (_) {
      return null;
    }
  }

  // ------------------------ Mapping ------------------------

  factory TransactionEntry.fromMap(Map<String, Object?> m) {
    return TransactionEntry(
      id: _asString(m['id'])!, // id doit exister
      remoteId: _asString(m['remoteId']),
      code: _asString(m['code']),
      description: _asString(m['description']),
      amount: _asInt(m['amount']),
      typeEntry: _asString(m['typeEntry']) ?? 'DEBIT',
      dateTransaction: _parseDate(m['dateTransaction']) ?? DateTime.now(),
      status: _asString(m['status']),
      entityName: _asString(m['entityName']),
      entityId: _asString(m['entityId']),
      accountId: _asString(m['accountId']), // ✅ nullable, plus de cast error
      categoryId: _asString(m['categoryId']),
      companyId: _asString(m['companyId']),
      customerId: _asString(m['customerId']),
      createdAt: _parseDate(m['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(m['updatedAt']) ?? DateTime.now(),
      deletedAt: _parseDate(m['deletedAt']),
      syncAt: _parseDate(m['syncAt']),
      version: _asInt(m['version']),
      isDirty: _asBool(m['isDirty'], fallback: true),
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
      'accountId': accountId, // ✅ peut rester null
      'categoryId': categoryId,
      'companyId': companyId,
      'customerId': customerId,
      'createdAt': f(createdAt),
      'updatedAt': f(updatedAt),
      'deletedAt': f(deletedAt),
      'syncAt': f(syncAt),
      'version': version,
      'isDirty': isDirty ? 1 : 0,
    };
  }

  // ------------------------ Copy ------------------------

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
    String? accountId, // <-- nullable
    String? categoryId,
    String? companyId,
    String? customerId,
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
      accountId: accountId ?? this.accountId, // ✅
      categoryId: categoryId ?? this.categoryId,
      companyId: companyId ?? this.companyId,
      customerId: customerId ?? this.customerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}
