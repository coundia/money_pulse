/// Domain entity for savings goals with mapping and progress helpers.

import 'package:uuid/uuid.dart';

class SavingGoal {
  final String id;
  final String? remoteId;
  final String name;
  final String? description;
  final int targetCents;
  final int savedCents;
  final DateTime? dueDate;
  final String? accountId;
  final String? companyId;
  final int priority;
  final int isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final int version;
  final int isDirty;

  const SavingGoal({
    required this.id,
    this.remoteId,
    required this.name,
    this.description,
    required this.targetCents,
    this.savedCents = 0,
    this.dueDate,
    this.accountId,
    this.companyId,
    this.priority = 3,
    this.isArchived = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.version = 0,
    this.isDirty = 1,
  });

  factory SavingGoal.newDraft({
    String? name,
    int targetCents = 0,
    String? accountId,
    String? companyId,
    DateTime? dueDate,
    int priority = 3,
  }) {
    final now = DateTime.now();
    return SavingGoal(
      id: const Uuid().v4(),
      name: name ?? 'Objectif',
      targetCents: targetCents,
      savedCents: 0,
      accountId: accountId,
      companyId: companyId,
      dueDate: dueDate,
      priority: priority,
      isArchived: 0,
      createdAt: now,
      updatedAt: now,
      version: 0,
      isDirty: 1,
    );
  }

  SavingGoal copyWith({
    String? id,
    String? remoteId,
    String? name,
    String? description,
    int? targetCents,
    int? savedCents,
    DateTime? dueDate,
    String? accountId,
    String? companyId,
    int? priority,
    int? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    int? version,
    int? isDirty,
  }) {
    return SavingGoal(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      description: description ?? this.description,
      targetCents: targetCents ?? this.targetCents,
      savedCents: savedCents ?? this.savedCents,
      dueDate: dueDate ?? this.dueDate,
      accountId: accountId ?? this.accountId,
      companyId: companyId ?? this.companyId,
      priority: priority ?? this.priority,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  bool get isCompleted => targetCents > 0 && savedCents >= targetCents;
  int get remainingCents =>
      targetCents > savedCents ? (targetCents - savedCents) : 0;
  double get progress =>
      targetCents <= 0 ? 0 : (savedCents / targetCents).clamp(0, 1);

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'remoteId': remoteId,
      'name': name,
      'description': description,
      'targetCents': targetCents,
      'savedCents': savedCents,
      'dueDate': dueDate?.toIso8601String(),
      'accountId': accountId,
      'companyId': companyId,
      'priority': priority,
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncAt': syncAt?.toIso8601String(),
      'version': version,
      'isDirty': isDirty,
    };
  }

  static SavingGoal fromMap(Map<String, Object?> m) {
    DateTime? parse(String? s) => s == null ? null : DateTime.parse(s);
    return SavingGoal(
      id: m['id'] as String,
      remoteId: m['remoteId'] as String?,
      name: m['name'] as String,
      description: m['description'] as String?,
      targetCents: (m['targetCents'] as num).toInt(),
      savedCents: (m['savedCents'] as num).toInt(),
      dueDate: parse(m['dueDate'] as String?),
      accountId: m['accountId'] as String?,
      companyId: m['companyId'] as String?,
      priority: (m['priority'] as num).toInt(),
      isArchived: (m['isArchived'] as num).toInt(),
      createdAt: DateTime.parse(m['createdAt'] as String),
      updatedAt: DateTime.parse(m['updatedAt'] as String),
      deletedAt: parse(m['deletedAt'] as String?),
      syncAt: parse(m['syncAt'] as String?),
      version: (m['version'] as num).toInt(),
      isDirty: (m['isDirty'] as num).toInt(),
    );
  }
}
