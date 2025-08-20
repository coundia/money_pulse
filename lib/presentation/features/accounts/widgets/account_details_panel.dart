// Right-drawer details panel for an account; shows balances in major units using Formatters (save x100, show /100), FR labels, EN code.
import 'package:flutter/material.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

class AccountDetailsPanel extends StatelessWidget {
  final Account account;
  final VoidCallback? onEdit;
  final VoidCallback? onMakeDefault;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onAdjust;

  const AccountDetailsPanel({
    super.key,
    required this.account,
    this.onEdit,
    this.onMakeDefault,
    this.onDelete,
    this.onShare,
    this.onAdjust,
  });

  String _money(int cents, {String? currency}) {
    if (currency != null && currency.isNotEmpty) {
      return Formatters.amountWithCurrencyFromCents(
        cents,
        symbol: currency,
        fractionDigits: 0,
      );
    }
    return Formatters.amountFromCents(cents);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = (account.description?.isNotEmpty ?? false)
        ? account.description!
        : (account.code?.isNotEmpty ?? false)
        ? account.code!
        : 'Compte';
    final subtitle = [
      if ((account.code ?? '').isNotEmpty) account.code!,
      if ((account.currency ?? '').isNotEmpty) account.currency!,
      account.isDefault == 1 ? 'Par défaut' : null,
    ].whereType<String>().join(' • ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du compte'),
        actions: [
          if (onShare != null)
            IconButton(
              tooltip: 'Partager',
              onPressed: onShare,
              icon: const Icon(Icons.ios_share),
            ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  onEdit?.call();
                  break;
                case 'default':
                  onMakeDefault?.call();
                  break;
                case 'adjust':
                  onAdjust?.call();
                  break;
                case 'delete':
                  onDelete?.call();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Modifier'),
                ),
              ),
              const PopupMenuItem(
                value: 'default',
                child: ListTile(
                  leading: Icon(Icons.star),
                  title: Text('Définir par défaut'),
                ),
              ),
              const PopupMenuItem(
                value: 'adjust',
                child: ListTile(
                  leading: Icon(Icons.tune),
                  title: Text('Ajuster le solde'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Supprimer'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
              child: const Icon(Icons.account_balance_wallet),
            ),
            title: Text(title, style: Theme.of(context).textTheme.titleLarge),
            subtitle: subtitle.isEmpty ? null : Text(subtitle),
            trailing: FilledButton.icon(
              onPressed: onAdjust,
              icon: const Icon(Icons.tune),
              label: const Text('Ajuster'),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Metric(
                label: 'Solde actuel',
                value: _money(account.balance, currency: account.currency),
                emphasis: true,
              ),
              _Metric(
                label: 'Solde précédent',
                value: _money(
                  account.balancePrev ?? 0,
                  currency: account.currency,
                ),
              ),
              _Metric(
                label: 'Bloqué',
                value: _money(
                  account.balanceBlocked ?? 0,
                  currency: account.currency,
                ),
              ),
              _Metric(
                label: 'Mise à jour',
                value: Formatters.dateFull(account.updatedAt),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Informations'),
                ),
                const Divider(height: 1),
                _KvRow(label: 'Code', value: account.code ?? '—'),
                _KvRow(label: 'Devise', value: account.currency ?? '—'),
                _KvRow(
                  label: 'Statut',
                  value: (account.status ?? '').isEmpty ? '—' : account.status!,
                ),
                _KvRow(
                  label: 'Par défaut',
                  value: account.isDefault == 1 ? 'Oui' : 'Non',
                ),
                _KvRow(
                  label: 'Créé le',
                  value: Formatters.dateFull(account.createdAt),
                ),
                _KvRow(
                  label: 'Dernière maj',
                  value: Formatters.dateFull(account.updatedAt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasis;
  const _Metric({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasis
        ? Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.titleMedium;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  final String label;
  final String value;
  const _KvRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(dense: true, title: Text(label), trailing: Text(value));
  }
}
