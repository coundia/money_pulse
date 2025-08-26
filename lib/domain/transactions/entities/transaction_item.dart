import 'package:equatable/equatable.dart';

class TransactionItem extends Equatable {
  final String id;
  final String transactionId;
  final String? productId;
  final String? localId;
  final String? remoteId;
  final String? label;
  final int quantity;
  final String? unitId;
  final int unitPrice;
  final int total;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final int version;
  final bool isDirty;

  const TransactionItem({
    required this.id,
    required this.transactionId,
    this.productId,
    this.label,
    required this.quantity,
    this.unitId,
    required this.unitPrice,
    required this.total,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.version = 0,
    this.isDirty = true,
    this.remoteId,
    this.localId,
  });

  TransactionItem copyWith({
    String? id,
    String? transactionId,
    String? productId,
    String? label,
    int? quantity,
    String? unitId,
    int? unitPrice,
    int? total,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    int? version,
    bool? isDirty,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      productId: productId ?? this.productId,
      label: label ?? this.label,
      quantity: quantity ?? this.quantity,
      unitId: unitId ?? this.unitId,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  factory TransactionItem.fromMap(Map<String, Object?> m) {
    DateTime? _dt(Object? v) =>
        v == null ? null : DateTime.tryParse(v as String);
    int _i(Object? v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
    return TransactionItem(
      id: m['id'] as String,
      transactionId: m['transactionId'] as String,
      productId: m['productId'] as String?,
      label: m['label'] as String?,
      quantity: _i(m['quantity']),
      unitId: m['unitId'] as String?,
      unitPrice: _i(m['unitPrice']),
      total: _i(m['total']),
      notes: m['notes'] as String?,
      createdAt: _dt(m['createdAt']) ?? DateTime.now(),
      updatedAt: _dt(m['updatedAt']) ?? DateTime.now(),
      deletedAt: _dt(m['deletedAt']),
      syncAt: _dt(m['syncAt']),
      version: _i(m['version']),
      isDirty: _i(m['isDirty']) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'productId': productId,
      'label': label,
      'quantity': quantity,
      'unitId': unitId,
      'unitPrice': unitPrice,
      'total': total,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncAt': syncAt?.toIso8601String(),
      'version': version,
      'isDirty': isDirty ? 1 : 0,
    };
  }

  @override
  List<Object?> get props => [
    id,
    transactionId,
    productId,
    label,
    quantity,
    unitId,
    unitPrice,
    total,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
    syncAt,
    version,
    isDirty,
  ];
}
