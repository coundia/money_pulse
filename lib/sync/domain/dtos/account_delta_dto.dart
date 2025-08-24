import 'package:money_pulse/sync/domain/sync_delta_type.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';

class AccountDeltaDto {
  final String? id; // remote id if UPDATE/DELETE
  final String localId; // ALWAYS set (local PK)
  final String code;
  final String? description;
  final String? currency;
  final String? typeAccount;
  final bool isDefault;
  final String? status;

  final int? balance;
  final int? balancePrev;
  final int? balanceBlocked;
  final int? balanceInit;
  final int? balanceGoal;
  final int? balanceLimit;

  final String syncAt;
  final String operation; // CREATE | UPDATE | DELETE

  AccountDeltaDto._({
    required this.id,
    required this.localId,
    required this.code,
    required this.description,
    required this.currency,
    required this.typeAccount,
    required this.isDefault,
    required this.status,
    required this.balance,
    required this.balancePrev,
    required this.balanceBlocked,
    required this.balanceInit,
    required this.balanceGoal,
    required this.balanceLimit,
    required this.syncAt,
    required this.operation,
  });

  /// `a` is your row (Account), fields accessed via dynamic to stay infra-agnostic.
  factory AccountDeltaDto.fromEntity(dynamic a, SyncDeltaType t, DateTime now) {
    final nowIso = (now.isUtc ? now : now.toUtc()).toIso8601String();
    final localId = (a.localId as String?) ?? (a.id as String);
    final isUpdateOrDelete = t != SyncDeltaType.create;

    return AccountDeltaDto._(
      id: isUpdateOrDelete ? a.remoteId as String? : null,
      localId: localId,
      code: a.code as String? ?? '',
      description: a.description as String?,
      currency: a.currency as String?,
      typeAccount: a.typeAccount as String?,
      isDefault: (a.isDefault as int? ?? 0) == 1,
      status: a.status as String?,
      balance: a.balance as int?,
      balancePrev: a.balance_prev as int? ?? a.balancePrev as int?,
      balanceBlocked: a.balance_blocked as int? ?? a.balanceBlocked as int?,
      balanceInit: a.balance_init as int? ?? a.balanceInit as int?,
      balanceGoal: a.balance_goal as int? ?? a.balanceGoal as int?,
      balanceLimit: a.balance_limit as int? ?? a.balanceLimit as int?,
      syncAt: nowIso,
      operation: t.op,
    );
  }

  Map<String, Object?> toJson() => {
    if (id != null) 'id': id,
    'localId': localId,
    'code': code,
    'description': description,
    'currency': currency,
    'typeAccount': typeAccount,
    'isDefault': isDefault,
    'status': status,
    'balance': balance,
    'balancePrev': balancePrev,
    'balanceBlocked': balanceBlocked,
    'balanceInit': balanceInit,
    'balanceGoal': balanceGoal,
    'balanceLimit': balanceLimit,
    'syncAt': syncAt,
    'operation': operation,
  };
}
