/// Simple shield to temporarily suppress auto refreshes when external pickers return to the app.

class RefocusShield {
  static DateTime? _until;

  static void activate({Duration duration = const Duration(seconds: 3)}) {
    _until = DateTime.now().add(duration);
  }

  static bool get isActive {
    final u = _until;
    if (u == null) return false;
    if (DateTime.now().isAfter(u)) {
      _until = null;
      return false;
    }
    return true;
  }

  static void clear() {
    _until = null;
  }
}
