// Delta DTO for account_users push.
import 'package:money_pulse/sync/domain/sync_delta_type.dart';
import 'package:money_pulse/sync/domain/sync_delta_type_ext.dart';

class AccountUserDeltaDto {
  final String? id;
  final String localId;
  final String? remoteId;

  final String account;
  final String? user;
  final String? email;
  final String? phone;
  final String? role;
  final String? status;
  final String? invitedBy;
  final String? invitedAt;
  final String? acceptedAt;
  final String? revokedAt;
  final String? createdBy;

  final String syncAt;
  final String operation; // CREATE | UPDATE | DELETE

  AccountUserDeltaDto._({
    required this.id,
    required this.localId,
    required this.remoteId,
    required this.account,
    required this.user,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.invitedBy,
    required this.invitedAt,
    required this.acceptedAt,
    required this.revokedAt,
    required this.createdBy,
    required this.syncAt,
    required this.operation,
  });

  factory AccountUserDeltaDto.fromEntity(
    dynamic e,
    SyncDeltaType t,
    DateTime now,
  ) {
    final nowIso = (now.isUtc ? now : now.toUtc()).toIso8601String();
    final localId = (e.localId as String?) ?? (e.id as String);
    final isUpdateOrDelete = t != SyncDeltaType.create;
    String? fmt(DateTime? d) => d?.toUtc().toIso8601String();

    return AccountUserDeltaDto._(
      id: isUpdateOrDelete ? e.remoteId as String? : null,
      localId: localId,
      remoteId: e.remoteId as String?,
      account: e.account as String,
      user: e.user as String?,
      email: e.email as String?,
      phone: e.phone as String?,
      role: e.role as String?,
      status: e.status as String?,
      invitedBy: e.invitedBy as String?,
      invitedAt: fmt(e.invitedAt as DateTime?),
      acceptedAt: fmt(e.acceptedAt as DateTime?),
      revokedAt: fmt(e.revokedAt as DateTime?),
      createdBy: e.createdBy as String?,
      syncAt: nowIso,
      operation: t.op,
    );
  }

  Map<String, Object?> toJson() => {
    'id': remoteId ?? id,
    'localId': localId,
    'remoteId': remoteId,
    'account': account,
    'user': user,
    'email': email,
    'phone': phone,
    'role': role,
    'status': status,
    'invitedBy': invitedBy,
    'invitedAt': invitedAt,
    'acceptedAt': acceptedAt,
    'revokedAt': revokedAt,
    'createdBy': createdBy,
    'syncAt': syncAt,
    'operation': operation,
    'type': operation.toUpperCase(),
  };
}
