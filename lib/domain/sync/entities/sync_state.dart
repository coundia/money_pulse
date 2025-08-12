class SyncState {
  final int? id;
  final String entityTable;
  final DateTime? lastSyncAt;
  final String? lastCursor;
  final DateTime updatedAt;

  const SyncState({
    required this.id,
    required this.entityTable,
    required this.lastSyncAt,
    required this.lastCursor,
    required this.updatedAt,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final iso = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(iso);
  }

  factory SyncState.fromMap(Map<String, Object?> m) => SyncState(
    id: (m['id'] as num?)?.toInt(),
    entityTable: m['entityTable'] as String,
    lastSyncAt: _parseDate(m['lastSyncAt']),
    lastCursor: m['lastCursor'] as String?,
    updatedAt: _parseDate(m['updatedAt']) ?? DateTime.now(),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'entityTable': entityTable,
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'lastCursor': lastCursor,
    'updatedAt': updatedAt.toIso8601String(),
  };

  SyncState copyWith({
    int? id,
    String? entityTable,
    DateTime? lastSyncAt,
    String? lastCursor,
    DateTime? updatedAt,
  }) => SyncState(
    id: id ?? this.id,
    entityTable: entityTable ?? this.entityTable,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    lastCursor: lastCursor ?? this.lastCursor,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
