// DTO for product delta payloads.
import 'package:jaayko/presentation/shared/formatters.dart';
import 'package:jaayko/sync/domain/sync_delta_type.dart';
import 'package:jaayko/sync/domain/sync_delta_type_ext.dart';

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
  final String? account;
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
    required this.account,
    required this.operation,
  });

  static String? _trimOrNull(Object? v) {
    return Formatters.trimOrNull(v);
  }

  factory ProductDeltaDto.fromEntity(dynamic p, SyncDeltaType t, DateTime now) {
    final isUpdateOrDelete = t != SyncDeltaType.create;
    final nowIso = (now.isUtc ? now : now.toUtc()).toIso8601String();
    final localId = (p.localId as String?) ?? (p.id as String);

    final rawCode = _trimOrNull(p.code);
    final rawName = _trimOrNull(p.name);
    final normalizedCode = rawCode ?? rawName;
    final normalizedName = rawName ?? rawCode;

    return ProductDeltaDto._(
      id: isUpdateOrDelete ? p.remoteId as String? : null,
      localId: localId,
      account: _trimOrNull(p.account),
      remoteId: _trimOrNull(p.remoteId),
      code: normalizedCode,
      name: normalizedName,
      description: _trimOrNull(p.description),
      barcode: _trimOrNull(p.barcode),
      unitId: _trimOrNull(p.unitId),
      categoryId: _trimOrNull(p.categoryId),
      defaultPrice: p.defaultPrice as int?,
      purchasePrice: p.purchasePrice as int?,
      statuses: _trimOrNull(p.statuses),
      syncAt: nowIso,
      operation: t.op,
    );
  }

  Map<String, Object?> toJson() => {
    'id': remoteId ?? id,
    'localId': localId,
    'remoteId': remoteId,
    'code': code,
    'name': name,
    'description': description,
    'barcode': barcode,
    'unitId': unitId,
    'account': account,
    'category': categoryId,
    'defaultPrice': defaultPrice,
    'purchasePrice': purchasePrice,
    'statuses': statuses,
    'syncAt': syncAt,
    'operation': operation,
    'type': operation.toUpperCase(),
  };
}
