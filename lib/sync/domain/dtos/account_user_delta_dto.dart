/* Delta DTO for account_users push with identity/message support and robust DateTime parsing. */
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
  final String? identity;
  final String? message;

  final String syncAt;
  final String operation;

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
    required this.identity,
    required this.message,
    required this.syncAt,
    required this.operation,
  });

  static DateTime? _asDateTimeUtc(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toUtc();
    return null;
  }

  static String? _fmtIso(DateTime? d) => d?.toIso8601String();

  factory AccountUserDeltaDto.fromEntity(
    dynamic e,
    SyncDeltaType t,
    DateTime now,
  ) {
    final nowIso = (now.isUtc ? now : now.toUtc()).toIso8601String();
    final localId = (e.localId as String?) ?? (e.id as String);
    final isUpdateOrDelete = t != SyncDeltaType.create;

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
      invitedAt: _fmtIso(_asDateTimeUtc(e.invitedAt)),
      acceptedAt: _fmtIso(_asDateTimeUtc(e.acceptedAt)),
      revokedAt: _fmtIso(_asDateTimeUtc(e.revokedAt)),
      createdBy: e.createdBy as String?,
      identity: e.identity as String?,
      message: e.message as String?,
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
    'identity': identity,
    'message': message,
    'syncAt': syncAt,
    'operation': operation,
    'type': operation.toUpperCase(),
  };
}
