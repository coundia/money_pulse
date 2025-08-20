// Compact amount chip for goal/limit with status (normal/reached/exceeded). Signals when a goal/limit is reached (FR labels, EN code).
import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

enum GoalLimitChipKind { goal, limit }

enum GoalLimitStatus { normal, reached, exceeded }

class GoalLimitChip extends StatelessWidget {
  final GoalLimitChipKind kind;
  final GoalLimitStatus status;
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
    this.status = GoalLimitStatus.normal,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Base colors by kind
    Color bg = kind == GoalLimitChipKind.goal
        ? cs.tertiaryContainer
        : cs.primaryContainer;
    Color fg = kind == GoalLimitChipKind.goal
        ? cs.onTertiaryContainer
        : cs.onPrimaryContainer;
    IconData ic = icon;

    // Status-driven overrides
    if (status == GoalLimitStatus.reached) {
      bg = cs.secondaryContainer;
      fg = cs.onSecondaryContainer;
      ic = Icons.check_circle;
    } else if (status == GoalLimitStatus.exceeded) {
      bg = cs.errorContainer;
      fg = cs.onErrorContainer;
      ic = Icons.error_rounded;
    }

    final money = Formatters.amountFromCents(amountCents);
    final cur = (currency ?? '').trim();

    // Human label when reached/exceeded
    String stateLabel;
    if (status == GoalLimitStatus.reached) {
      stateLabel = kind == GoalLimitChipKind.goal
          ? 'Objectif atteint'
          : 'Plafond atteint';
    } else if (status == GoalLimitStatus.exceeded) {
      stateLabel = 'Plafond dépassé';
    } else {
      stateLabel = label; // 'Objectif' | 'Plafond'
    }

    final text = '$stateLabel: $money${cur.isNotEmpty ? ' $cur' : ''}';

    return Semantics(
      label: text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
