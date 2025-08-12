import 'package:flutter/foundation.dart';

@immutable
class Unit {
  final String id;
  final String? remoteId;

  /// Code court (ex: "kg", "L", "pc")
  final String code;

  /// Nom lisible (ex: "Kilogramme")
  final String? name;
  final String? description;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;

  /// Incrémente à chaque mise à jour locale
  final int version;

  /// 1 si en attente de synchronisation, sinon 0
  final int isDirty;

  const Unit({
    required this.id,
    required this.remoteId,
    required this.code,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.syncAt,
    required this.version,
    required this.isDirty,
  });

  Unit copyWith({
    String? id,
    String? remoteId,
    String? code,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    int? version,
    int? isDirty,
  }) {
    return Unit(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  /// Parse a DateTime from TEXT stored in SQLite.
  /// Accepts both "YYYY-MM-DD HH:MM:SS" and ISO "YYYY-MM-DDTHH:MM:SS" forms.
  static DateTime? _dt(Object? v) {
    final s = v as String?;
    if (s == null || s.isEmpty) return null;
    final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  factory Unit.fromMap(Map<String, Object?> m) {
    return Unit(
      id: m['id'] as String,
      remoteId: m['remoteId'] as String?,
      code: (m['code'] as String).trim(),
      name: (m['name'] as String?)?.trim(),
      description: (m['description'] as String?)?.trim(),
      createdAt: _dt(m['createdAt']) ?? DateTime.now(),
      updatedAt: _dt(m['updatedAt']) ?? DateTime.now(),
      deletedAt: _dt(m['deletedAt']),
      syncAt: _dt(m['syncAt']),
      version: (m['version'] as int?) ?? 0,
      isDirty: (m['isDirty'] as int?) ?? 1,
    );
  }

  Map<String, Object?> toMap() {
    String? toIso(DateTime? d) => d?.toIso8601String();

    return {
      'id': id,
      'remoteId': remoteId,
      'code': code,
      'name': name,
      'description': description,
      'createdAt': toIso(createdAt),
      'updatedAt': toIso(updatedAt),
      'deletedAt': toIso(deletedAt),
      'syncAt': toIso(syncAt),
      'version': version,
      'isDirty': isDirty,
    };
  }

  @override
  String toString() =>
      'Unit(id: $id, code: $code, name: $name, version: $version, dirty: $isDirty)';
}
