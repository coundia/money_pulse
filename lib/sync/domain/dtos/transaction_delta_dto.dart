import 'package:jaayko/domain/transactions/entities/transaction_entry.dart';
import 'package:jaayko/sync/domain/sync_delta_type.dart';

class TransactionDeltaDto {
  final String id;
  final String? remoteId;
  final String? localId;
  final String? code;
  final String? description;
  final int amount;
  final String typeEntry;
  final String type;
  final DateTime updatedAt;
  final DateTime? syncAt;
  final String? account;
  final String? category;
  final String? company;

  final String? customer;
  final DateTime dateTransaction;
  final String? status;

  TransactionDeltaDto({
    required this.id,
    this.remoteId,
    this.localId,
    required this.account,
    this.code,
    this.description,
    required this.amount,
    required this.typeEntry,
    required this.type,
    required this.updatedAt,

    this.syncAt,
    this.category,
    this.company,
    this.customer,
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
      syncAt: now,
      account: e.accountId,
      category: e.categoryId,
      company: e.companyId,
      customer: e.customerId,
      dateTransaction: e.dateTransaction,
      status: e.status,
      typeEntry: e.typeEntry,
    );
  }

  Map<String, Object?> toJson() => {
    'id': remoteId ?? id,
    'remoteId': remoteId,
    'localId': localId,
    'code': code,
    'description': description,
    'amount': amount,
    'type': type,
    'typeEntry': typeEntry,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'account': account,
    'category': category,
    'company': company,
    'customer': customer,
    'dateTransaction': dateTransaction.toUtc().toIso8601String(),
    'status': status,
  };
}
