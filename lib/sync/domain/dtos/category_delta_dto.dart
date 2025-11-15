import 'package:jaayko/domain/categories/entities/category.dart';
import 'package:jaayko/sync/domain/sync_delta_type.dart';

class CategoryDeltaDto {
  final String id;
  final String? remoteId;
  final String? name;
  final String? localId;
  final String code;
  final String? description;
  final String? account;
  final String type;
  final String typeEntry;
  final DateTime updatedAt;

  CategoryDeltaDto({
    required this.id,
    this.remoteId,
    this.account,
    this.localId,
    this.name,
    required this.code,
    this.description,
    required this.type,
    required this.typeEntry,
    required this.updatedAt,
  });

  factory CategoryDeltaDto.fromEntity(
    Category c,
    SyncDeltaType t,
    DateTime now,
  ) {
    return CategoryDeltaDto(
      id: c.id,
      remoteId: c.remoteId,
      localId: c.localId,
      code: c.code,
      account: c.account,
      name: c.code,
      description: c.description,
      type: t.name,
      typeEntry: c.typeEntry,
      updatedAt: now,
    );
  }

  Map<String, Object?> toJson() => {
    'id': remoteId ?? id,
    'remoteId': remoteId,
    'localId': localId,
    'account': account,
    'code': code,
    'name': code,
    'description': description,
    'typeEntry': typeEntry,
    'operation': type,
    'updatedAt': updatedAt.toIso8601String(),
    'type': type.toUpperCase(),
  };
}
