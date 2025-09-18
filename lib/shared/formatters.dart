// Helpers for French date/time/amount formatting.
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
}
