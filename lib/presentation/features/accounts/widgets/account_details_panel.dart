// Right-drawer details panel to view an account with type-aware chips, budget/limit alerts and x100 amount display.

import 'package:flutter/material.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class AccountDetailsPanel extends StatelessWidget {
  final Account account;
  final VoidCallback? onEdit;
  final VoidCallback? onMakeDefault;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  const AccountDetailsPanel({
    super.key,
    required this.account,
    this.onEdit,
    this.onMakeDefault,
    this.onDelete,
    this.onShare,
  });

  static const _typeLabelsFr = {
    'CASH': 'Espèces',
    'BANK': 'Banque',
    'MOBILE': 'Mobile money',
    'SAVINGS': 'Épargne',
    'CREDIT': 'Crédit',
    'BUDGET_MAX': 'Budget maximum',
    'OTHER': 'Autre',
  };

  String _fmtMoney(int cents, String? currency) {
    final v = Formatters.amountFromCents(cents);
    return currency == null ? v : '$v ${currency.toUpperCase()}';
  }

  String _date(DateTime? d) => d == null ? '—' : Formatters.dateFull(d);

  @override
  Widget build(BuildContext context) {
    final a = account;
    final typeFr = _typeLabelsFr[a.typeAccount] ?? (a.typeAccount ?? '—');

    final isBudgetMax = a.typeAccount == 'BUDGET_MAX';
    final isCredit = a.typeAccount == 'CREDIT';
    final limit = a.balanceLimit;
    final overLimit = limit > 0 && a.balance > limit;
    final remaining = limit > 0 ? (limit - a.balance) : 0;

    final chips = <Widget>[];
    if (isBudgetMax) {
      chips.add(
        Chip(
          avatar: const Icon(Icons.flag_circle_outlined),
          label: Text('Budget max: ${_fmtMoney(a.balanceLimit, a.currency)}'),
        ),
      );
      chips.add(
        Chip(
          avatar: const Icon(Icons.account_balance_wallet_outlined),
          label: Text(
            remaining >= 0
                ? 'Reste: ${_fmtMoney(remaining, a.currency)}'
                : 'Dépassement: ${_fmtMoney(remaining.abs(), a.currency)}',
          ),
        ),
      );
      if (overLimit) {
        chips.add(
          Chip(
            avatar: const Icon(Icons.warning_amber),
            label: const Text('Dépassement du budget'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            labelStyle: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        );
      }
    } else {
      if (a.balanceInit > 0) {
        chips.add(
          Chip(
            avatar: const Icon(Icons.flag),
            label: Text('Initial: ${_fmtMoney(a.balanceInit, a.currency)}'),
          ),
        );
      }
      if (a.balanceGoal > 0) {
        chips.add(
          Chip(
            avatar: const Icon(Icons.track_changes),
            label: Text('Objectif: ${_fmtMoney(a.balanceGoal, a.currency)}'),
          ),
        );
      }
      if (a.balanceLimit > 0) {
        chips.add(
          Chip(
            avatar: const Icon(Icons.warning_amber),
            label: Text('Limite: ${_fmtMoney(a.balanceLimit, a.currency)}'),
          ),
        );
      }
      if (isCredit && overLimit) {
        chips.add(
          Chip(
            avatar: const Icon(Icons.priority_high),
            label: const Text('Au-delà du plafond'),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            labelStyle: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        );
      }
    }

    final amountStyle = overLimit
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.error,
          )
        : Theme.of(context).textTheme.titleLarge;

    final showGoalProgress = !isBudgetMax && a.balanceGoal > 0;
    final progress = showGoalProgress
        ? (a.balance / a.balanceGoal).clamp(0, 1).toDouble()
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du compte'),
        actions: [
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.share),
            tooltip: 'Partager',
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
          ),
          if (onMakeDefault != null)
            IconButton(
              onPressed: onMakeDefault,
              icon: const Icon(Icons.star),
              tooltip: 'Définir par défaut',
            ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(
              a.description?.isNotEmpty == true
                  ? a.description!
                  : (a.code ?? 'Compte'),
            ),
            subtitle: Text(typeFr),
            trailing: Text(
              _fmtMoney(a.balance, a.currency),
              style: amountStyle,
            ),
          ),
          const Divider(),
          if (chips.isNotEmpty)
            Wrap(runSpacing: 8, spacing: 8, children: chips),
          if (showGoalProgress) ...[
            const SizedBox(height: 12),
            Text(
              'Progression vers objectif',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 10),
            ),
            const SizedBox(height: 6),
            Text('${(progress * 100).toStringAsFixed(0)} %'),
          ],
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Période'),
            subtitle: Text(
              '${_date(a.dateStartAccount)} → ${_date(a.dateEndAccount)}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text('Mis à jour'),
            subtitle: Text(_date(a.updatedAt)),
          ),
        ],
      ),
    );
  }
}
