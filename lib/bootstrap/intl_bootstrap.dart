import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> ensureIntlFr() async {
  Intl.defaultLocale = 'fr_FR';
  await Future.wait([
    initializeDateFormatting('fr'),
    initializeDateFormatting('fr_FR'),
  ]);
}
