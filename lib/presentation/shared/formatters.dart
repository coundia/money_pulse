// Utilities for French amount/date formatting with robust cents<->major conversions (save x100, show /100).
import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _intFr = NumberFormat.decimalPattern('fr_FR');

  static NumberFormat _fracFr(int digits) =>
      NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: digits);

  static String amountFromCents(int cents, {int fractionDigits = 0}) {
    final major = cents / 100.0;
    if (fractionDigits == 0) {
      final intMajor = major.truncate();
      return _intFr.format(intMajor);
    }
    return _fracFr(fractionDigits).format(major);
  }

  static String amountWithCurrencyFromCents(
    int cents, {
    String symbol = '',
    int fractionDigits = 0,
  }) {
    final major = cents / 100.0;
    return NumberFormat.currency(
      locale: 'fr_FR',
      symbol: symbol,
      decimalDigits: fractionDigits,
    ).format(major);
  }

  static String dateFull(DateTime dt) {
    return DateFormat.yMMMMEEEEd('fr_FR').add_Hm().format(dt);
  }

  static String dateShort(DateTime dt) {
    return DateFormat.yMd('fr_FR').add_Hm().format(dt);
  }

  static String dateVeryShort(DateTime dt) {
    return DateFormat.yMd('fr_FR').format(dt);
  }

  static String timeHm(DateTime dt) {
    return DateFormat.Hm('fr_FR').format(dt);
  }

  static int toMinorFromMajorString(String text) {
    if (text.trim().isEmpty) return 0;
    final s0 = text
        .replaceAll('\u00A0', '')
        .replaceAll('\u202F', '')
        .replaceAll('\u2009', '')
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (s0.isEmpty) return 0;
    final isNeg = s0.startsWith('-') || s0.contains('−');
    final lastDot = s0.lastIndexOf('.');
    final lastComma = s0.lastIndexOf(',');
    final sep = lastDot > lastComma ? lastDot : lastComma;

    String intPart, decPart;
    if (sep >= 0) {
      intPart = s0.substring(0, sep).replaceAll(RegExp(r'[^0-9]'), '');
      decPart = s0.substring(sep + 1).replaceAll(RegExp(r'[^0-9]'), '');
    } else {
      intPart = s0.replaceAll(RegExp(r'[^0-9]'), '');
      decPart = '';
    }

    if (intPart.isEmpty) intPart = '0';
    if (decPart.isEmpty) decPart = '0';

    final normalized = '${isNeg ? '-' : ''}$intPart.${decPart}';
    final v = double.tryParse(normalized) ?? 0.0;
    return (v * 100).round();
  }

  static String majorRawFromMinor(
    int cents, {
    int decimals = 0,
    bool group = false,
  }) {
    final major = cents / 100.0;
    if (decimals == 0) {
      final value = major.floor();
      return group ? _intFr.format(value) : value.toStringAsFixed(0);
    }
    final s = major.toStringAsFixed(decimals);
    return group ? _fracFr(decimals).format(major) : s.replaceAll('.', ',');
  }

  static String? trimOrNull(Object? v) {
    final s = (v is String) ? v : (v?.toString());
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}
