// Right-drawer details panel to view an account with budgets, dates and actions.

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

  String _fmtMoney(int cents, String? currency) {
    final v = Formatters.amountFromCents(cents);
    return currency == null ? v : '$v $currency';
  }

  String _date(DateTime? d) => d == null ? '—' : Formatters.dateFull(d);

  @override
  Widget build(BuildContext context) {
    final a = account;
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
            subtitle: Text(a.typeAccount ?? '—'),
            trailing: Text(
              _fmtMoney(a.balance, a.currency),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.flag),
                label: Text('Initial: ${_fmtMoney(a.balanceInit, a.currency)}'),
              ),
              Chip(
                avatar: const Icon(Icons.track_changes),
                label: Text(
                  'Objectif: ${_fmtMoney(a.balanceGoal, a.currency)}',
                ),
              ),
              Chip(
                avatar: const Icon(Icons.warning_amber),
                label: Text('Limite: ${_fmtMoney(a.balanceLimit, a.currency)}'),
              ),
            ],
          ),
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
