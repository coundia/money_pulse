// Domain model: represents a granted access session after code verification.
class AccessGrant {
  final String email;
  final String token;
  final DateTime grantedAt;

  const AccessGrant({
    required this.email,
    required this.token,
    required this.grantedAt,
  });
}
