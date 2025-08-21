/* Waitlist entry entity with optional contact info and json helpers. */
import 'dart:convert';

class WaitlistEntry {
  final String? email;
  final String? phone;
  final String? message;
  final DateTime savedAt;

  const WaitlistEntry({
    this.email,
    this.phone,
    this.message,
    required this.savedAt,
  });

  bool get hasAnyContact =>
      (email != null && email!.trim().isNotEmpty) ||
      (phone != null && phone!.trim().isNotEmpty);

  Map<String, dynamic> toMap() => {
    'email': email,
    'phone': phone,
    'message': message,
    'savedAt': savedAt.toIso8601String(),
  };

  factory WaitlistEntry.fromMap(Map<String, dynamic> m) => WaitlistEntry(
    email: (m['email'] as String?)?.trim().isEmpty == true
        ? null
        : m['email'] as String?,
    phone: (m['phone'] as String?)?.trim().isEmpty == true
        ? null
        : m['phone'] as String?,
    message: (m['message'] as String?)?.trim().isEmpty == true
        ? null
        : m['message'] as String?,
    savedAt: DateTime.tryParse(m['savedAt'] as String? ?? '') ?? DateTime.now(),
  );

  String toJson() => jsonEncode(toMap());

  factory WaitlistEntry.fromJson(String s) =>
      WaitlistEntry.fromMap(jsonDecode(s) as Map<String, dynamic>);
}
