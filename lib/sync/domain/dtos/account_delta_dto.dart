/* DTO for Account delta push payload. */
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/sync/domain/sync_delta_type.dart';

class AccountDeltaDto {
  final String id;
  final String type;
  final String? remoteId;
  final String? code;
  final String? description;
  final String? status;
  final String? currency;
  final String? typeAccount;
  final int balance;
  final int balancePrev;
  final int balanceBlocked;
  final int balanceInit;
  final int balanceGoal;
  final int balanceLimit;
  final String? dateStartAccount;
  final String? dateEndAccount;
  final bool isDefault;
  final int version;
  final String? syncAt;

  const AccountDeltaDto({
    required this.id,
    required this.type,
    this.remoteId,
    this.code,
    this.description,
    this.status,
    this.currency,
    this.typeAccount,
    required this.balance,
    required this.balancePrev,
    required this.balanceBlocked,
    required this.balanceInit,
    required this.balanceGoal,
    required this.balanceLimit,
    this.dateStartAccount,
    this.dateEndAccount,
    required this.isDefault,
    required this.version,
    this.syncAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'remoteId': remoteId,
    'code': code,
    'description': description,
    'status': status,
    'currency': currency,
    'typeAccount': typeAccount,
    'balance': balance,
    'balancePrev': balancePrev,
    'balanceBlocked': balanceBlocked,
    'balanceInit': balanceInit,
    'balanceGoal': balanceGoal,
    'balanceLimit': balanceLimit,
    'dateStartAccount': dateStartAccount,
    'dateEndAccount': dateEndAccount,
    'isDefault': isDefault,
    'version': version,
    'syncAt': syncAt,
  };

  static AccountDeltaDto fromEntity(Account a, SyncDeltaType t, DateTime now) {
    return AccountDeltaDto(
      id: a.id,
      type: t.wire,
      remoteId: a.remoteId,
      code: a.code,
      description: a.description,
      status: a.status,
      currency: a.currency,
      typeAccount: a.typeAccount,
      balance: a.balance,
      balancePrev: a.balancePrev,
      balanceBlocked: a.balanceBlocked,
      balanceInit: a.balanceInit,
      balanceGoal: a.balanceGoal,
      balanceLimit: a.balanceLimit,
      dateStartAccount: a.dateStartAccount?.toUtc().toIso8601String(),
      dateEndAccount: a.dateEndAccount?.toUtc().toIso8601String(),
      isDefault: a.isDefault,
      version: a.version,
      syncAt: now.toUtc().toIso8601String(),
    );
  }
}
