// Circular avatar for account type with default star badge.
import 'package:flutter/material.dart';

class AccountAvatar extends StatelessWidget {
  final String? type;
  final bool isDefault;
  const AccountAvatar({super.key, required this.type, this.isDefault = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = _iconFor(type);
    final bg = _bg(cs, type);
    final fg = _fg(cs, type);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          backgroundColor: bg,
          foregroundColor: fg,
          child: Icon(icon),
        ),
        if (isDefault)
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star, size: 12, color: cs.onPrimary),
            ),
          ),
      ],
    );
  }

  IconData _iconFor(String? t) {
    switch (t) {
      case 'BANK':
        return Icons.account_balance;
      case 'MOBILE':
        return Icons.smartphone;
      case 'SAVINGS':
        return Icons.savings_outlined;
      case 'CREDIT':
        return Icons.credit_card;
      case 'BUDGET_MAX':
        return Icons.flag_circle_outlined;
      case 'CASH':
        return Icons.payments_outlined;
      default:
        return Icons.wallet_outlined;
    }
  }

  Color _bg(ColorScheme cs, String? t) {
    switch (t) {
      case 'BANK':
        return cs.primaryContainer;
      case 'MOBILE':
        return cs.secondaryContainer;
      case 'SAVINGS':
        return cs.tertiaryContainer;
      case 'CREDIT':
        return cs.errorContainer.withOpacity(.65);
      case 'BUDGET_MAX':
        return cs.surfaceTint.withOpacity(.20);
      case 'CASH':
        return cs.surfaceVariant;
      default:
        return cs.surfaceVariant;
    }
  }

  Color _fg(ColorScheme cs, String? t) {
    switch (t) {
      case 'BANK':
        return cs.onPrimaryContainer;
      case 'MOBILE':
        return cs.onSecondaryContainer;
      case 'SAVINGS':
        return cs.onTertiaryContainer;
      case 'CREDIT':
        return cs.onErrorContainer;
      case 'BUDGET_MAX':
        return cs.onSurface;
      case 'CASH':
        return cs.onSurfaceVariant;
      default:
        return cs.onSurfaceVariant;
    }
  }
}
