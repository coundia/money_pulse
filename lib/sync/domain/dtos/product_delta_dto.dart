// DTO for product delta payloads.
import 'package:money_pulse/sync/domain/sync_delta_type.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';

class ProductDeltaDto {
  final String? id;
  final String localId;
  final String? remoteId;
  final String? code;
  final String? name;
  final String? description;
  final String? barcode;
  final String? unitId;
  final String? categoryId;
  final int? defaultPrice;
  final int? purchasePrice;
  final String? statuses;
  final String syncAt;
  final String operation;

  ProductDeltaDto._({
    required this.id,
    required this.localId,
    required this.remoteId,
    required this.code,
    required this.name,
    required this.description,
    required this.barcode,
    required this.unitId,
    required this.categoryId,
    required this.defaultPrice,
    required this.purchasePrice,
    required this.statuses,
    required this.syncAt,
    required this.operation,
  });

  factory ProductDeltaDto.fromEntity(dynamic p, SyncDeltaType t, DateTime now) {
    final isUpdateOrDelete = t != SyncDeltaType.create;
    final nowIso = (now.isUtc ? now : now.toUtc()).toIso8601String();
    final localId = (p.localId as String?) ?? (p.id as String);

    return ProductDeltaDto._(
      id: isUpdateOrDelete ? p.remoteId as String? : null,
      localId: localId,
      remoteId: p.remoteId as String?,
      code: p.code ?? p.name,
      name: p.name ?? p.code,
      description: p.description as String?,
      barcode: p.barcode as String?,
      unitId: p.unitId as String?,
      categoryId: p.categoryId as String?,
      defaultPrice: p.defaultPrice as int?,
      purchasePrice: p.purchasePrice as int?,
      statuses: p.statuses as String?,
      syncAt: nowIso,
      operation: t.op,
    );
  }

  Map<String, Object?> toJson() => {
    if (id != null) 'id': id,
    'localId': localId,
    'remoteId': remoteId,
    'code': code,
    'name': name,
    'description': description,
    'barcode': barcode,
    'unitId': unitId,
    'category': categoryId,
    'defaultPrice': defaultPrice,
    'purchasePrice': purchasePrice,
    'statuses': statuses,
    'syncAt': syncAt,
    'operation': operation,
    'type': operation.toUpperCase(),
  };
}
