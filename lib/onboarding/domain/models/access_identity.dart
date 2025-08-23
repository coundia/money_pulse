// Value object describing identity used to request/verify access.
class AccessIdentity {
  final String username;
  final String? email;
  final String? phone;
  final String? name;
  final String? notes;

  const AccessIdentity({
    required this.username,
    this.email,
    this.phone,
    this.name,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'username': username,
      'email': email,
      'phone': phone,
      'name': name,
      'notes': notes,
    }..removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));
    return map;
  }
}
