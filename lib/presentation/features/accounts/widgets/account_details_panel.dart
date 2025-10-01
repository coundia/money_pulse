// Right-drawer details panel for an account with full balances, remaining amounts,
// and progress tracking (FR labels, EN code). Bottom actions presented as a Row (icons only).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import '../account_share_screen.dart';

class AccountDetailsPanel extends StatelessWidget {
  final Account account;
  final VoidCallback? onEdit;
  final VoidCallback? onMakeDefault;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onAdjust;

  /// Async callback to save (POST/PUT) to remote server.
  /// If null, the bottom "Enregistrer" action is hidden.
  final Future<void> Function()? onSaveRemote;

  const AccountDetailsPanel({
    super.key,
    required this.account,
    this.onEdit,
    this.onMakeDefault,
    this.onDelete,
    this.onShare,
    this.onAdjust,
    this.onSaveRemote,
  });

  String _money(int cents, {String? currency}) {
    final cur = (currency ?? '').trim();
    if (cur.isNotEmpty) {
      return Formatters.amountWithCurrencyFromCents(
        cents,
        symbol: cur,
        fractionDigits: 0,
      );
    }
    return Formatters.amountFromCents(cents);
  }

  String _deltaText(int delta, {String? currency}) {
    final pref = delta > 0 ? '+' : '';
    return '$pref${_money(delta, currency: currency)}';
  }

  static const Map<String, String> _typeLabelsFr = {
    'CASH': 'Espèces',
    'BANK': 'Banque',
    'MOBILE': 'Mobile money',
    'SAVINGS': 'Épargne',
    'CREDIT': 'Crédit',
    'BUDGET_MAX': 'Budget maximum',
    'OTHER': 'Autre',
  };

  Future<void> _doSaveRemote(BuildContext context) async {
    if (onSaveRemote == null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SavingDialog(),
    );
    try {
      await onSaveRemote!.call();
      if (context.mounted) {
        Navigator.of(context).pop(); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synchronisé avec le serveur')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de synchronisation: $e')),
        );
      }
    }
  }

  void _openShare(BuildContext context) {
    openAccountShareScreen<void>(
      context,
      accountId: account.id,
      accountName: account.code ?? 'Compte',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final title = (account.description?.isNotEmpty ?? false)
        ? account.description!
        : 'Compte';

    final subtitle = [
      if ((account.currency ?? '').isNotEmpty) account.currency!,
      account.isDefault ? 'Par défaut' : null,
    ].whereType<String>().join(' • ');

    final current = account.balance;
    final previous = account.balancePrev;
    final blocked = account.balanceBlocked;
    final available = (current - blocked).clamp(
      -9223372036854775808,
      9223372036854775807,
    );
    final init = account.balanceInit;
    final goal = account.balanceGoal;
    final limit = account.balanceLimit;

    final remainingToGoal = goal > 0 ? goal - current : null;
    final remainingToLimit = limit > 0 ? limit - current : null;

    final hasGoal = goal > 0;
    final hasLimit = limit > 0;

    double _ratio(int value, int target) {
      if (target <= 0) return 0;
      final r = value / target;
      if (r.isNaN) return 0;
      return r.clamp(0, 1);
    }

    final goalRatio = hasGoal ? _ratio(current, goal) : 0.0;
    final limitRatio = hasLimit ? _ratio(current, limit) : 0.0;

    final typeFr =
        _typeLabelsFr[account.typeAccount ?? ''] ?? _typeLabelsFr['OTHER']!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du compte'),
        actions: [
          IconButton(
            tooltip: 'Copier les infos',
            onPressed: () async {
              final txt = [
                'Compte: ${account.description ?? account.code ?? '—'}',
                if ((account.currency ?? '').isNotEmpty)
                  'Devise: ${account.currency}',
                'Solde: ${_money(current, currency: account.currency)}',
                'Statut: ${account.status ?? '—'}',
                'Par défaut: ${account.isDefault ? 'Oui' : 'Non'}',
                'ID: ${account.id}',
                'RemoteId: ${account.remoteId ?? '—'}',
              ].join('\n');
              await Clipboard.setData(ClipboardData(text: txt));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Détails copiés')));
              }
            },
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'Partager',
            onPressed: onShare ?? () => _openShare(context),
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
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Modifier'),
                ),
              ),
              const PopupMenuItem(
                value: 'default',
                child: ListTile(
                  leading: Icon(Icons.star_outline),
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
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: cs.error),
                  title: const Text('Supprimer'),
                  iconColor: cs.error,
                  textColor: cs.error,
                ),
              ),
            ],
          ),
        ],
      ),

      // --- Corps : informations structurées ---
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimaryContainer,
                    child: const Icon(Icons.account_balance_wallet),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (account.isDefault)
                              Tooltip(
                                message: 'Compte par défaut',
                                child: Icon(
                                  Icons.star,
                                  color: cs.primary,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Métriques
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Metric(
                label: 'Solde actuel',
                value: _money(current, currency: account.currency),
                emphasis: true,
              ),
              _Metric(
                label: 'Solde précédent',
                value: _money(previous, currency: account.currency),
              ),
              _Metric(
                label: 'Variation',
                value: _deltaText(
                  current - previous,
                  currency: account.currency,
                ),
                valueColor: (current - previous) == 0
                    ? Theme.of(context).textTheme.titleMedium?.color
                    : (current - previous) > 0
                    ? Colors.green
                    : cs.error,
              ),
              _Metric(
                label: 'Bloqué',
                value: _money(blocked, currency: account.currency),
              ),
              _Metric(
                label: 'Disponible',
                value: _money(available, currency: account.currency),
              ),
              if (init > 0)
                _Metric(
                  label: 'Solde initial',
                  value: _money(init, currency: account.currency),
                ),
              if (hasGoal)
                _Metric(
                  label: 'Objectif',
                  value: _money(goal, currency: account.currency),
                ),
              if (hasGoal)
                _Metric(
                  label: (remainingToGoal ?? 0) < 0
                      ? 'Dépassement objectif'
                      : 'Restant vers objectif',
                  value: _money(
                    (remainingToGoal ?? 0).abs(),
                    currency: account.currency,
                  ),
                  valueColor: (remainingToGoal ?? 0) < 0
                      ? cs.error
                      : Theme.of(context).textTheme.titleMedium?.color,
                ),
              if (hasLimit)
                _Metric(
                  label: 'Limite',
                  value: _money(limit, currency: account.currency),
                ),
              if (hasLimit)
                _Metric(
                  label: (remainingToLimit ?? 0) < 0
                      ? 'Dépassement limite'
                      : 'Restant avant limite',
                  value: _money(
                    (remainingToLimit ?? 0).abs(),
                    currency: account.currency,
                  ),
                  valueColor: (remainingToLimit ?? 0) < 0
                      ? cs.error
                      : Theme.of(context).textTheme.titleMedium?.color,
                ),
              _Metric(
                label: 'Mise à jour',
                value: Formatters.dateFull(account.updatedAt),
              ),
            ],
          ),

          if (hasGoal || hasLimit) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasGoal) ...[
                      Text(
                        'Progression vers objectif',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      _ProgressRow(
                        ratio: goalRatio,
                        leading: _money(current, currency: account.currency),
                        trailing: _money(goal, currency: account.currency),
                        barColor: cs.primary,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (hasLimit) ...[
                      Text(
                        'Progression vers limite',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      _ProgressRow(
                        ratio: limitRatio,
                        leading: _money(current, currency: account.currency),
                        trailing: _money(limit, currency: account.currency),
                        barColor: (remainingToLimit ?? 0) < 0
                            ? cs.error
                            : cs.tertiary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          if (account.dateStartAccount != null ||
              account.dateEndAccount != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Période'),
                subtitle: Text(
                  [
                    if (account.dateStartAccount != null)
                      'Du ${Formatters.dateFull(account.dateStartAccount!)}',
                    if (account.dateEndAccount != null)
                      'au ${Formatters.dateFull(account.dateEndAccount!)}',
                  ].join(' '),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Informations'),
                ),
                const Divider(height: 1),
                _KvRow(
                  label: 'Devise',
                  value: account.currency?.trim().isEmpty ?? true
                      ? '—'
                      : account.currency!.trim(),
                ),
                _KvRow(label: 'Type', value: typeFr),
                _KvRow(
                  label: 'Statut',
                  value: (account.status ?? '').isEmpty ? '—' : account.status!,
                ),
                _KvRow(
                  label: 'Par défaut',
                  value: account.isDefault ? 'Oui' : 'Non',
                ),

                _KvRow(
                  label: 'Crée par',
                  value: account.createdBy?.trim().isEmpty ?? true
                      ? '—'
                      : account.createdBy!.trim(),
                ),

                _KvRow(
                  label: 'Créé le',
                  value: Formatters.dateFull(account.createdAt),
                ),
                _KvRow(
                  label: 'Dernière maj',
                  value: Formatters.dateFull(account.updatedAt),
                ),
                _KvRow(label: 'ID.', value: account.id ?? "-"),
                _KvRow(label: 'IDL.', value: account.localId ?? "-"),
                _KvRow(label: 'IDR.', value: account.remoteId ?? "-"),
              ],
            ),
          ),
          const SizedBox(height: 90), // espace pour la bottom bar
        ],
      ),

      // --- Barre d’actions persistante en bas (ROW - icons only) ---
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              if (onAdjust != null)
                Expanded(
                  child: Tooltip(
                    message: 'Ajuster',
                    child: OutlinedButton(
                      onPressed: onAdjust,
                      child: const Icon(Icons.tune),
                    ),
                  ),
                ),
              if (onAdjust != null) const SizedBox(width: 8),
              if (onEdit != null)
                Expanded(
                  child: Tooltip(
                    message: 'Modifier',
                    child: OutlinedButton(
                      onPressed: onEdit,
                      child: const Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
              if (onEdit != null) const SizedBox(width: 8),
              if (onSaveRemote != null)
                Expanded(
                  child: Tooltip(
                    message: 'Enregistrer sur le serveur',
                    child: FilledButton(
                      onPressed: () => _doSaveRemote(context),
                      child: const Icon(Icons.cloud_upload_outlined),
                    ),
                  ),
                ),
              if (onSaveRemote != null) const SizedBox(width: 8),
              if (onDelete != null)
                Expanded(
                  child: Tooltip(
                    message: 'Supprimer',
                    child: FilledButton.tonal(
                      onPressed: onDelete,
                      child: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingDialog extends StatelessWidget {
  const _SavingDialog();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Synchronisation en cours...'),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasis;
  final Color? valueColor;
  const _Metric({
    required this.label,
    required this.value,
    this.emphasis = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).textTheme.titleMedium?.color;
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
          Text(value, style: style?.copyWith(color: valueColor ?? baseColor)),
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

class _ProgressRow extends StatelessWidget {
  final double ratio;
  final String leading;
  final String trailing;
  final Color barColor;
  const _ProgressRow({
    required this.ratio,
    required this.leading,
    required this.trailing,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 86,
          child: Text(
            leading,
            textAlign: TextAlign.left,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: cs.surfaceVariant.withOpacity(.5),
              color: barColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 86,
          child: Text(
            trailing,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}
