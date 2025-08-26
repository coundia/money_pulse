// Debt entity mapped to 'debt' table with minimal helpers.
import 'package:uuid/uuid.dart';

class Debt {
  final String id;
  final String? remoteId;
  final String? localId;
  final String? code;
  final String? notes;
  final int balance;
  final int balanceDebt;
  final DateTime? dueDate;
  final String? statuses;
  final String? customerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final int version;
  final int isDirty;

  const Debt({
    required this.id,
    this.remoteId,
    this.localId,
    this.code,
    this.notes,
    this.balance = 0,
    this.balanceDebt = 0,
    this.dueDate,
    this.statuses,
    this.customerId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.version = 0,
    this.isDirty = 1,
  });

  Debt copyWith({
    String? id,
    String? remoteId,
    String? code,
    String? notes,
    int? balance,
    int? balanceDebt,
    DateTime? dueDate,
    String? statuses,
    String? customerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    int? version,
    int? isDirty,
  }) {
    return Debt(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      code: code ?? this.code,
      notes: notes ?? this.notes,
      balance: balance ?? this.balance,
      balanceDebt: balanceDebt ?? this.balanceDebt,
      dueDate: dueDate ?? this.dueDate,
      statuses: statuses ?? this.statuses,
      customerId: customerId ?? this.customerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  static Debt newOpenForCustomer(String customerId) {
    final now = DateTime.now();
    return Debt(
      id: const Uuid().v4(),
      customerId: customerId,
      statuses: 'OPEN',
      balance: 0,
      balanceDebt: 0,
      createdAt: now,
      updatedAt: now,
      version: 0,
      isDirty: 1,
    );
  }

  static Debt fromMap(Map<String, Object?> m) {
    DateTime? _dt(String? s) => s == null ? null : DateTime.parse(s);
    return Debt(
      id: m['id'] as String,
      remoteId: m['remoteId'] as String?,
      code: m['code'] as String?,
      notes: m['notes'] as String?,
      balance: (m['balance'] as int?) ?? 0,
      balanceDebt: (m['balanceDebt'] as int?) ?? 0,
      dueDate: _dt(m['dueDate'] as String?),
      statuses: m['statuses'] as String?,
      customerId: m['customerId'] as String?,
      createdAt: DateTime.parse(m['createdAt'] as String),
      updatedAt: DateTime.parse(m['updatedAt'] as String),
      deletedAt: _dt(m['deletedAt'] as String?),
      syncAt: _dt(m['syncAt'] as String?),
      version: (m['version'] as int?) ?? 0,
      isDirty: (m['isDirty'] as int?) ?? 1,
    );
  }

  Map<String, Object?> toMap() {
    String? _s(DateTime? d) => d?.toIso8601String();
    return {
      'id': id,
      'remoteId': remoteId,
      'code': code,
      'notes': notes,
      'balance': balance,
      'balanceDebt': balanceDebt,
      'dueDate': _s(dueDate),
      'statuses': statuses,
      'customerId': customerId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': _s(deletedAt),
      'syncAt': _s(syncAt),
      'version': version,
      'isDirty': isDirty,
    };
  }
}
