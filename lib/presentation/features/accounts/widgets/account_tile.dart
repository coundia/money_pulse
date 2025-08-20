// Account list tile with type-aware visuals, remaining amount, and savings goal progress moved into subtitle to avoid bottom overflow.
import 'package:flutter/material.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class AccountTile extends StatelessWidget {
  final Account account;
  final String balanceText;
  final String updatedAtText;
  final VoidCallback? onView;
  final VoidCallback? onAdjust;
  final VoidCallback? onMakeDefault;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final Future<void> Function(String action)? onMenuAction;

  const AccountTile({
    super.key,
    required this.account,
    required this.balanceText,
    required this.updatedAtText,
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

    final subtitleLine = [
      typeFr,
      if (updatedAtText.isNotEmpty) updatedAtText,
    ].join(' · ');

    final int balanceCents = account.balance;
    final int? limit = account.balanceLimit;
    final int? goal = account.balanceGoal;

    int? remainingCents;
    String remainingLabel = 'Restant';
    if (limit != null && limit > 0) {
      remainingCents = limit - balanceCents;
      remainingLabel = 'Restant';
    } else if (goal != null && goal > 0) {
      remainingCents = goal - balanceCents;
      remainingLabel = 'Objectif';
    }

    String _fmt(int cents) {
      final n = Formatters.amountFromCents(cents);
      final cur = (account.currency ?? '').trim();
      return cur.isEmpty ? n : '$n $cur';
    }

    String _fmtOnly(int cents) {
      final n = Formatters.amountFromCents(cents);
      return n;
    }

    final bool hasRemaining = remainingCents != null;
    final bool isOver = (remainingCents ?? 0) < 0;
    final int absRemain = (remainingCents ?? 0).abs();

    final bool isSavings = type == 'SAVINGS';
    final bool hasSavingsGoal = isSavings && (goal != null && goal > 0);
    final double goalRatio = hasSavingsGoal
        ? (balanceCents.toDouble() / goal!.toDouble()).clamp(0.0, 1.0)
        : 0.0;
    final int goalPercent = hasSavingsGoal
        ? ((balanceCents / (goal!.toDouble())) * 100).clamp(0, 100).round()
        : 0;

    final hasMenu =
        onMenuAction != null ||
        onAdjust != null ||
        onMakeDefault != null ||
        onDelete != null ||
        onShare != null ||
        onView != null;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant.withOpacity(.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        isThreeLine: hasSavingsGoal,
        onTap: onView,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Stack(
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
                  child: Icon(Icons.star, size: 12, color: cs.onPrimary),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitleLine, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (hasSavingsGoal) ...[
              const SizedBox(height: 6),
              Text(
                '$remainingLabel: ${_fmtOnly(absRemain)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              Semantics(
                label: '$goalPercent%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: goalRatio,
                    minHeight: 6,
                    backgroundColor: cs.surfaceVariant.withOpacity(.5),
                    color: cs.tertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    balanceText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (hasRemaining)
                    Text(
                      isOver
                          ? 'Dépassé de ${_fmt(absRemain)}'
                          : '${_fmt(goal!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isOver ? cs.error : cs.onSurfaceVariant,
                        fontWeight: isOver ? FontWeight.w700 : FontWeight.w500,
                      ),
                    )
                  else
                    Text('—', style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
            if (hasMenu) ...[
              const SizedBox(width: 6),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                onSelected: (v) async {
                  if (onMenuAction != null) {
                    await onMenuAction!(v);
                    return;
                  }
                  switch (v) {
                    case 'view':
                      onView?.call();
                      break;
                    case 'adjust':
                      onAdjust?.call();
                      break;
                    case 'default':
                      onMakeDefault?.call();
                      break;
                    case 'share':
                      onShare?.call();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'view',
                    child: ListTile(
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('Voir'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'adjust',
                    child: ListTile(
                      leading: Icon(Icons.tune),
                      title: Text('Ajuster le solde'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'default',
                    child: ListTile(
                      leading: Icon(Icons.star),
                      title: Text('Définir par défaut'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.ios_share),
                      title: Text('Partager'),
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Supprimer'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
