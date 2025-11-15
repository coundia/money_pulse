// Compact pill chip for goal or limit amounts shown in list rows.
import 'package:flutter/material.dart';
import 'package:jaayko/presentation/shared/formatters.dart';

class MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;

  const MiniChip({
    super.key,
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  factory MiniChip.goal({required int amountCents, String? currency}) {
    return MiniChip(
      icon: Icons.flag_outlined,
      label:
          'Objectif ${Formatters.amountFromCents(amountCents)}${(currency ?? '').isNotEmpty ? ' $currency' : ''}',
      bg: Colors.transparent,
      fg: Colors.transparent,
    );
  }

  factory MiniChip.limit({required int amountCents, String? currency}) {
    return MiniChip(
      icon: Icons.speed_rounded,
      label:
          'Plafond ${Formatters.amountFromCents(amountCents)}${(currency ?? '').isNotEmpty ? ' $currency' : ''}',
      bg: Colors.transparent,
      fg: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isGoal = label.startsWith('Objectif');
    final usedBg = bg == Colors.transparent
        ? (isGoal ? cs.tertiaryContainer : cs.primaryContainer)
        : bg;
    final usedFg = fg == Colors.transparent
        ? (isGoal ? cs.onTertiaryContainer : cs.onPrimaryContainer)
        : fg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: usedBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: usedFg),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: usedFg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
