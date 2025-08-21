/// Value object for validating email format.
class EmailAddress {
  final String value;

  EmailAddress._(this.value);

  static EmailAddress? tryParse(String raw) {
    final v = raw.trim();
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
    if (!ok) return null;
    return EmailAddress._(v);
  }

  @override
  String toString() => value;
}
