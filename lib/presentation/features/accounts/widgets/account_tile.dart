// Account list row with shared marker when not creator; FR labels, EN code; no inline context menu (handled by parent).
import 'package:flutter/material.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class AccountTile extends StatelessWidget {
  final Account account;
  final String balanceText;
  final String updatedAtText;
  final bool isCreator; // NEW: mark owner vs shared
  final VoidCallback? onView;
  final VoidCallback? onAdjust; // kept for API compatibility (unused here)
  final VoidCallback? onMakeDefault; // kept for API compatibility (unused here)
  final VoidCallback? onDelete; // kept for API compatibility (unused here)
  final VoidCallback? onShare; // kept for API compatibility (unused here)
  final Future<void> Function(String action)? onMenuAction; // kept (unused)

  const AccountTile({
    super.key,
    required this.account,
    required this.balanceText,
    required this.updatedAtText,
    this.isCreator = true, // default: owner
    this.onView,
    this.onAdjust,
    this.onMakeDefault,
    this.onDelete,
    this.onShare,
    this.onMenuAction,
  });

  static const Map<String, String> _typeLabelsFr = {
    'CASH': 'Espèces',
    'BANK': 'Banque',
    'MOBILE': 'Mobile money',
    'SAVINGS': 'Épargne',
    'CREDIT': 'Crédit',
    'BUDGET_MAX': 'Budget maximum',
    'OTHER': 'Autre',
  };

  static const Map<String, IconData> _typeIcons = {
    'CASH': Icons.payments_outlined,
    'BANK': Icons.account_balance,
    'MOBILE': Icons.smartphone,
    'SAVINGS': Icons.savings_outlined,
    'CREDIT': Icons.credit_card,
    'BUDGET_MAX': Icons.flag_circle_outlined,
    'OTHER': Icons.wallet_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final type = account.typeAccount ?? 'OTHER';
    final typeFr = _typeLabelsFr[type] ?? _typeLabelsFr['OTHER']!;
    final icon = _typeIcons[type] ?? _typeIcons['OTHER']!;
    final title = (account.description?.isNotEmpty == true)
        ? account.description!
        : 'Compte';

    final Color avatarBg = switch (type) {
      'BANK' => cs.primaryContainer,
      'CREDIT' => cs.errorContainer.withOpacity(.65),
      'SAVINGS' => cs.tertiaryContainer,
      'MOBILE' => cs.secondaryContainer,
      'BUDGET_MAX' => cs.surfaceTint.withOpacity(.20),
      'CASH' => cs.surfaceVariant,
      _ => cs.surfaceVariant,
    };
    final Color avatarFg = switch (type) {
      'BANK' => cs.onPrimaryContainer,
      'CREDIT' => cs.onErrorContainer,
      'SAVINGS' => cs.onTertiaryContainer,
      'MOBILE' => cs.onSecondaryContainer,
      'BUDGET_MAX' => cs.onSurface,
      'CASH' => cs.onSurfaceVariant,
      _ => cs.onSurfaceVariant,
    };

    final int balanceCents = account.balance;
    final int? limit = account.balanceLimit;
    final int? goal = account.balanceGoal;

    int? remainingCents;
    String remainingLabel = 'Restant';
    if ((limit ?? 0) > 0) {
      remainingCents = limit! - balanceCents;
      remainingLabel = 'Restant';
    } else if ((goal ?? 0) > 0) {
      remainingCents = goal! - balanceCents;
      remainingLabel = 'Vers objectif';
    }

    String _fmt(int cents) {
      final n = Formatters.amountFromCents(cents);
      final cur = (account.currency ?? '').trim();
      return cur.isEmpty ? n : '$n $cur';
    }

    final bool hasRemaining = remainingCents != null;
    final bool isOver = (remainingCents ?? 0) < 0;
    final int absRemain = (remainingCents ?? 0).abs();

    final bool isSavings = type == 'SAVINGS';
    final bool isCreditOrBudget = type == 'CREDIT' || type == 'BUDGET_MAX';

    final bool showGoalChip = isSavings && (goal ?? 0) > 0;
    final bool showLimitChip = isCreditOrBudget && (limit ?? 0) > 0;

    final bool hasSavingsGoal = isSavings && (goal ?? 0) > 0;
    final double goalRatio = hasSavingsGoal
        ? (balanceCents.toDouble() / goal!.toDouble()).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant.withOpacity(.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onView,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      backgroundColor: avatarBg,
                      foregroundColor: avatarFg,
                      child: Icon(icon),
                    ),
                    if (account.isDefault == 1)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withOpacity(.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.star,
                            size: 12,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    if (!isCreator)
                      Positioned(
                        left: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: cs.secondary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: cs.secondary.withOpacity(.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.group,
                            size: 12,
                            color: cs.onSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Title + optional shared tag and progress
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (!isCreator) ...[
                            const SizedBox(width: 6),
                            _MiniChip(
                              icon: Icons.group_outlined,
                              label: 'Partagé',
                              bg: cs.secondaryContainer,
                              fg: cs.onSecondaryContainer,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          typeFr,
                          if (updatedAtText.isNotEmpty) updatedAtText,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasSavingsGoal) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: goalRatio,
                            minHeight: 6,
                            backgroundColor: cs.surfaceVariant.withOpacity(.5),
                            color: cs.tertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Right block with amounts (no ellipsis/menu)
                Flexible(
                  fit: FlexFit.loose,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          balanceText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        if (hasRemaining)
                          Text(
                            isOver
                                ? 'Dépassé de ${_fmt(absRemain)}'
                                : 'Restant: ${_fmt(absRemain)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: isOver
                                      ? cs.error
                                      : cs.onSurfaceVariant,
                                  fontWeight: isOver
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          )
                        else
                          Text(
                            '—',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: [
                            if (isSavings && (goal ?? 0) > 0)
                              _MiniChip(
                                icon: Icons.flag_outlined,
                                label: 'Objectif ${_fmt(goal!)}',
                                bg: cs.tertiaryContainer,
                                fg: cs.onTertiaryContainer,
                              ),
                            if ((isCreditOrBudget) && (limit ?? 0) > 0)
                              _MiniChip(
                                icon: Icons.speed_rounded,
                                label: 'Plafond ${_fmt(limit!)}',
                                bg: cs.primaryContainer,
                                fg: cs.onPrimaryContainer,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
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
            label,
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
