/* DTO for Category delta push payload. */
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/sync/domain/sync_delta_type.dart';

class CategoryDeltaDto {
  final String id;
  final String type;
  final String code;
  final String? name;
  final String? remoteId;
  final String? description;
  final String typeEntry;
  final int version;
  final String? syncAt;

  const CategoryDeltaDto({
    required this.id,
    required this.type,
    required this.code,
    this.name,
    this.remoteId,
    this.description,
    required this.typeEntry,
    required this.version,
    this.syncAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'code': code,
    'name': name,
    'remoteId': remoteId,
    'description': description,
    'typeEntry': typeEntry,
    'version': version,
    'syncAt': syncAt,
    'is_active': true,
  };

  static CategoryDeltaDto fromEntity(
    Category c,
    SyncDeltaType t,
    DateTime now,
  ) {
    return CategoryDeltaDto(
      id: c.id,
      type: t.wire,
      code: c.code,
      name: c.code,
      remoteId: c.id,
      description: c.description,
      typeEntry: c.typeEntry,
      version: c.version,
      syncAt: now.toUtc().toIso8601String(),
    );
  }
}
