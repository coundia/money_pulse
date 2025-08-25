import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/sync/domain/sync_delta_type.dart';

class TransactionDeltaDto {
  final String id;
  final String? remoteId;
  final String? localId;
  final String? code;
  final String? description;
  final int amount;
  final String type;
  final DateTime updatedAt;
  final String? accountId;
  final String? categoryId;
  final String? companyId;
  final String? customerId;
  final DateTime dateTransaction;
  final String? status;

  TransactionDeltaDto({
    required this.id,
    this.remoteId,
    this.localId,
    this.code,
    this.description,
    required this.amount,
    required this.type,
    required this.updatedAt,
    this.accountId,
    this.categoryId,
    this.companyId,
    this.customerId,
    required this.dateTransaction,
    this.status,
  });

  factory TransactionDeltaDto.fromEntity(
    TransactionEntry e,
    SyncDeltaType t,
    DateTime now,
  ) {
    return TransactionDeltaDto(
      id: e.id,
      remoteId: e.remoteId,
      localId: e.localId,
      code: e.code,
      description: e.description,
      amount: e.amount,
      type: t.name,
      updatedAt: now,
      accountId: e.accountId,
      categoryId: e.categoryId,
      companyId: e.companyId,
      customerId: e.customerId,
      dateTransaction: e.dateTransaction,
      status: e.status,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'remoteId': remoteId,
    'localId': localId,
    'code': code,
    'description': description,
    'amount': amount,
    'operation': type,
    'updatedAt': updatedAt.toIso8601String(),
    'accountId': accountId,
    'categoryId': categoryId,
    'companyId': companyId,
    'customerId': customerId,
    'dateTransaction': dateTransaction.toIso8601String(),
    'status': status,
  };
}
