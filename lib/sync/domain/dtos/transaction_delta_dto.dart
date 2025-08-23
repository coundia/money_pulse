/* DTO for TransactionEntry delta push payload. */
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/sync/domain/sync_delta_type.dart';

class TransactionDeltaDto {
  final String id;
  final String type;
  final String? remoteId;
  final String? code;
  final String? description;
  final int amount;
  final String typeEntry;
  final String dateOperation;
  final String? status;
  final String? reference;
  final String? balance;
  final String? category;
  final String createdAt;
  final String updatedAt;
  final String? syncAt;
  final int version;

  const TransactionDeltaDto({
    required this.id,
    required this.type,
    this.remoteId,
    this.code,
    this.description,
    required this.amount,
    required this.typeEntry,
    required this.dateOperation,
    this.status,
    this.reference,
    this.balance,
    this.category,
    required this.createdAt,
    required this.updatedAt,
    this.syncAt,
    required this.version,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'remoteId': remoteId,
    'code': code,
    'description': description,
    'amount': amount,
    'typeEntry': typeEntry,
    'dateOperation': dateOperation,
    'status': status,
    'reference': reference,
    'balance': balance,
    'category': category,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'syncAt': syncAt,
    'version': version,
  };

  static TransactionDeltaDto fromEntity(
    TransactionEntry e,
    SyncDeltaType t,
    DateTime now,
  ) {
    return TransactionDeltaDto(
      id: e.id,
      type: t.wire,
      remoteId: e.remoteId,
      code: e.code,
      description: e.description,
      amount: e.amount,
      typeEntry: e.typeEntry,
      dateOperation: e.dateTransaction.toUtc().toIso8601String(),
      status: e.status,
      reference: e.code,
      balance: e.accountId,
      category: e.categoryId,
      createdAt: e.createdAt.toUtc().toIso8601String(),
      updatedAt: e.updatedAt.toUtc().toIso8601String(),
      syncAt: now.toUtc().toIso8601String(),
      version: e.version,
    );
  }
}
