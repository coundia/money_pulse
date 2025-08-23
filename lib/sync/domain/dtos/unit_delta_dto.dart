/* DTO for Unit delta push payload. */
class UnitDeltaDto {
  final String id;
  final String type;
  final String code;
  final String? name;
  final String? remoteId;
  final String? description;
  final int version;
  final String? syncAt;

  const UnitDeltaDto({
    required this.id,
    required this.type,
    required this.code,
    this.name,
    this.remoteId,
    this.description,
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
    'version': version,
    'syncAt': syncAt,
  };
}
