// Compact amount chip for goal/limit display in the app bar title (FR labels, EN code).
import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

enum GoalLimitChipKind { goal, limit }

class GoalLimitChip extends StatelessWidget {
  final GoalLimitChipKind kind;
  final int amountCents;
  final String? currency;
  final String label;
  final IconData icon;

  const GoalLimitChip({
    super.key,
    required this.kind,
    required this.amountCents,
    required this.label,
    required this.icon,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = switch (kind) {
      GoalLimitChipKind.goal => cs.tertiaryContainer,
      GoalLimitChipKind.limit => cs.primaryContainer,
    };
    final fg = switch (kind) {
      GoalLimitChipKind.goal => cs.onTertiaryContainer,
      GoalLimitChipKind.limit => cs.onPrimaryContainer,
    };
    final money = Formatters.amountFromCents(amountCents);
    final cur = (currency ?? '').trim();
    final text = '$label: $money${cur.isNotEmpty ? ' $cur' : ''}';

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
            text,
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
