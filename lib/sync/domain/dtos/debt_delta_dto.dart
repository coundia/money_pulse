/* DTO for Debt delta push payload. */
class DebtDeltaDto {
  final String id;
  final String type;
  final String? remoteId;
  final String? code;
  final String? notes;
  final int balance;
  final int balanceDebt;
  final String? dueDate;
  final String? statuses;
  final String? customerId;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int version;
  final String? syncAt;

  const DebtDeltaDto({
    required this.id,
    required this.type,
    this.remoteId,
    this.code,
    this.notes,
    required this.balance,
    required this.balanceDebt,
    this.dueDate,
    this.statuses,
    this.customerId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.version,
    this.syncAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'remoteId': remoteId,
    'code': code,
    'notes': notes,
    'balance': balance,
    'balanceDebt': balanceDebt,
    'dueDate': dueDate,
    'statuses': statuses,
    'customerId': customerId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'deletedAt': deletedAt,
    'version': version,
    'syncAt': syncAt,
  };
}
