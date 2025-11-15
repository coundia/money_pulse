// Small amount pill used to display a labeled amount (in cents) with accent or error tone.
import 'package:flutter/material.dart';
import 'package:jaayko/presentation/shared/formatters.dart';

class CustomerAmountPill extends StatelessWidget {
  final String label;
  final int cents;
  final bool danger;
  const CustomerAmountPill({
    super.key,
    required this.label,
    required this.cents,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = danger
        ? cs.error.withOpacity(0.10)
        : cs.primary.withOpacity(0.08);
    final fg = danger ? cs.error : cs.primary;

    return Semantics(
      label: label,
      value: Formatters.amountFromCents(cents),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label:',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: fg),
            ),
            const SizedBox(width: 6),
            Text(
              Formatters.amountFromCents(cents),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
