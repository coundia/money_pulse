import 'package:intl/intl.dart';

class Formatters {
  static String amountFromCents(int cents) {
    return NumberFormat.decimalPattern().format(cents / 100);
  }

  static String dateFull(DateTime dt) {
    return DateFormat.yMMMMEEEEd().add_Hm().format(dt);
  }

  static String timeHm(DateTime dt) {
    return DateFormat.Hm().format(dt);
  }

  static int toMinorFromMajorString(String text) {
    final s = text.replaceAll(RegExp(r'[^\d,.\-]'), '').replaceAll(' ', '');
    if (s.isEmpty) return 0;
    final normalized = s.replaceAll(',', '.');
    final v = double.tryParse(normalized) ?? 0.0;
    return (v * 100).round();
  }

  static String majorRawFromMinor(int cents, {int decimals = 0}) {
    final v = cents / 100;
    return v.toStringAsFixed(decimals);
  }
}
