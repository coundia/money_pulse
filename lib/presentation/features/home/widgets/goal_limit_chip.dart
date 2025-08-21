import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

enum GoalLimitChipKind { goal, limit }

enum GoalLimitStatus { normal, reached, exceeded }

class GoalLimitChip extends StatelessWidget {
  final GoalLimitChipKind kind;
  final GoalLimitStatus status;
  final int amountCents;
  final String currency;
  final String label;
  final IconData icon;
  final bool obscure; // NEW

  const GoalLimitChip({
    super.key,
    required this.kind,
    this.status = GoalLimitStatus.normal,
    required this.amountCents,
    required this.currency,
    required this.label,
    required this.icon,
    this.obscure = false, // NEW
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    switch (status) {
      case GoalLimitStatus.reached:
        bg = cs.tertiaryContainer.withOpacity(
          kind == GoalLimitChipKind.goal ? 1 : .85,
        );
        fg = cs.onTertiaryContainer;
        break;
      case GoalLimitStatus.exceeded:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        break;
      case GoalLimitStatus.normal:
      default:
        bg = kind == GoalLimitChipKind.goal
            ? cs.tertiaryContainer
            : cs.primaryContainer;
        fg = kind == GoalLimitChipKind.goal
            ? cs.onTertiaryContainer
            : cs.onPrimaryContainer;
        break;
    }

    final amount = obscure
        ? '•••'
        : Formatters.amountFromCents(amountCents) +
              (currency.isEmpty ? '' : ' $currency');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            '$label: $amount',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
