import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class MoneyText extends StatelessWidget {
  final int amountCents;
  final String currency;
  final TextStyle? style;
  const MoneyText({
    super.key,
    required this.amountCents,
    required this.currency,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(
      name: currency,
      decimalDigits: 0,
      symbol: '',
    );
    final v = Formatters.amountFromCents(amountCents);
    return Text('$v $currency', style: style);
  }
}
