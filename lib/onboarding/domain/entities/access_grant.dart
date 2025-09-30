/* Value object carrying access grant token, email, granted date, optional username and phone. */
class AccessGrant {
  final String email;
  final String token;
  final DateTime grantedAt;
  final String? username;
  final String? phone;
  final String? expiresAt;

  const AccessGrant({
    required this.email,
    required this.token,
    required this.grantedAt,
    this.username,
    this.phone,
    this.expiresAt,
  });

  AccessGrant copyWith({
    String? email,
    String? token,
    DateTime? grantedAt,
    String? username,
    String? phone,
    String? expiresAt,
  }) {
    return AccessGrant(
      email: email ?? this.email,
      token: token ?? this.token,
      grantedAt: grantedAt ?? this.grantedAt,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
