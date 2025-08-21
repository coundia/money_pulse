/// Value object for validating password rules.
class Password {
  final String value;

  Password._(this.value);

  static Password? tryParse(String raw) {
    final v = raw.trim();
    if (v.length < 6) return null;
    return Password._(v);
  }

  @override
  String toString() => value;
}
