/* Entity describing an account sharing membership with role and status; maps identity from either 'identity' or legacy 'identify'. */
class AccountUser {
  final String id;
  final String account;
  final String? user;
  final String? email;
  final String? identity;
  final String? phone;
  final String? role;
  final String? status;
  final String? invitedBy;
  final String? createdBy;
  final DateTime? invitedAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final DateTime? syncAt;
  final int version;
  final int isDirty;
  final String? remoteId;
  final String? localId;
  final String? message;

  const AccountUser({
    required this.id,
    required this.account,
    this.user,
    this.email,
    this.phone,
    this.identity,
    this.message,
    this.role,
    this.status,
    this.invitedBy,
    this.invitedAt,
    this.acceptedAt,
    this.revokedAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncAt,
    this.version = 0,
    this.isDirty = 1,
    this.remoteId,
    this.localId,
    this.createdBy,
  });

  AccountUser copyWith({
    String? id,
    String? account,
    String? user,
    String? email,
    String? phone,
    String? role,
    String? status,
    String? invitedBy,
    String? identity,
    String? message,
    DateTime? invitedAt,
    DateTime? acceptedAt,
    DateTime? revokedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? syncAt,
    int? version,
    int? isDirty,
    String? remoteId,
    String? localId,
  }) {
    return AccountUser(
      id: id ?? this.id,
      account: account ?? this.account,
      user: user ?? this.user,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      message: message ?? this.message,
      identity: identity ?? this.identity,
      role: role ?? this.role,
      status: status ?? this.status,
      invitedBy: invitedBy ?? this.invitedBy,
      invitedAt: invitedAt ?? this.invitedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      revokedAt: revokedAt ?? this.revokedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncAt: syncAt ?? this.syncAt,
      version: version ?? this.version,
      isDirty: isDirty ?? this.isDirty,
      remoteId: remoteId ?? this.remoteId,
      localId: localId ?? this.localId,
    );
  }

  static AccountUser fromMap(Map<String, Object?> m) {
    DateTime? _dt(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return AccountUser(
      id: m['id'] as String,
      account: m['account'] as String,
      user: m['user'] as String?,
      email: m['email'] as String?,
      phone: m['phone'] as String?,
      role: m['role'] as String?,
      status: m['status'] as String?,
      invitedBy: m['invitedBy'] as String?,
      invitedAt: _dt(m['invitedAt']),
      acceptedAt: _dt(m['acceptedAt']),
      revokedAt: _dt(m['revokedAt']),
      createdAt: _dt(m['createdAt']),
      updatedAt: _dt(m['updatedAt']),
      deletedAt: _dt(m['deletedAt']),
      syncAt: _dt(m['syncAt']),
      version: (m['version'] as int?) ?? 0,
      isDirty: (m['isDirty'] as int?) ?? 1,
      remoteId: m['remoteId'] as String?,
      localId: m['localId'] as String?,
      message: m['message'] as String?,
      identity: (m['identity'] ?? m['identify']) as String?,
    );
  }

  Map<String, Object?> toMap() {
    String? _iso(DateTime? d) => d?.toUtc().toIso8601String();
    return {
      'id': id,
      'account': account,
      'user': user,
      'email': email,
      'phone': phone,
      'role': role,
      'status': status,
      'invitedBy': invitedBy,
      'invitedAt': _iso(invitedAt),
      'acceptedAt': _iso(acceptedAt),
      'revokedAt': _iso(revokedAt),
      'createdAt': _iso(createdAt),
      'updatedAt': _iso(updatedAt),
      'deletedAt': _iso(deletedAt),
      'syncAt': _iso(syncAt),
      'version': version,
      'isDirty': isDirty,
      'remoteId': remoteId,
      'localId': localId,
      'identity': identity,
      'message': message,
    }..removeWhere((k, v) => v == null);
  }
}
