// Details panel for an account with actions and safe delete confirmation.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/key_value_row.dart';
import 'package:money_pulse/presentation/app/providers.dart';

class AccountDetailsPanel extends ConsumerWidget {
  final Account account;
  final VoidCallback? onEdit;
  final VoidCallback? onMakeDefault;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final bool confirmHere;

  const AccountDetailsPanel({
    super.key,
    required this.account,
    this.onEdit,
    this.onMakeDefault,
    this.onDelete,
    this.onShare,
    this.confirmHere = true,
  });

  String _fmtDate(DateTime? d) => d == null ? '—' : Formatters.dateFull(d);

  String _fmtMoney(int cents, String? code) {
    final a = Formatters.amountFromCents(cents);
    return code == null ? a : '$a $code';
  }

  bool _isDefault(Account a) {
    final v = a.isDefault;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return false;
  }

  Future<void> _copyAll(BuildContext context) async {
    final a = account;
    final text =
        'Compte: ${a.code ?? '—'}'
        '\nDescription: ${a.description ?? '—'}'
        '\nDevise: ${a.currency ?? '—'}'
        '\nSolde: ${_fmtMoney(a.balance, a.currency)}'
        '\nSolde précédent: ${_fmtMoney(a.balancePrev, a.currency)}'
        '\nSolde bloqué: ${_fmtMoney(a.balanceBlocked, a.currency)}'
        '\nPar défaut: ${_isDefault(a) ? 'Oui' : 'Non'}'
        '\nStatut: ${a.status ?? '—'}'
        '\nID distant: ${a.remoteId ?? '—'}'
        '\nCréé le: ${_fmtDate(a.createdAt)}'
        '\nMis à jour le: ${_fmtDate(a.updatedAt)}'
        '\nSupprimé le: ${_fmtDate(a.deletedAt)}'
        '\nSynchronisé le: ${_fmtDate(a.syncAt)}'
        '\nVersion: ${a.version}'
        '\nID: ${a.id}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Détails copiés dans le presse-papiers')),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le compte ?'),
        content: const Text(
          'Cette action est irréversible. Voulez-vous vraiment supprimer ce compte ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = account;
    final isDef = _isDefault(a);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fermer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Détails du compte'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).maybePop();
              onEdit?.call();
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          KeyValueRow(label: 'Code', value: a.code ?? '—'),
          KeyValueRow(label: 'Description', value: a.description ?? '—'),
          KeyValueRow(label: 'Devise', value: a.currency ?? '—'),
          const SizedBox(height: 8),
          KeyValueRow(label: 'Solde', value: _fmtMoney(a.balance, a.currency)),
          KeyValueRow(
            label: 'Solde précédent',
            value: _fmtMoney(a.balancePrev, a.currency),
          ),
          KeyValueRow(
            label: 'Solde bloqué',
            value: _fmtMoney(a.balanceBlocked, a.currency),
          ),
          const Divider(height: 24),
          KeyValueRow(label: 'Par défaut', value: isDef ? 'Oui' : 'Non'),
          KeyValueRow(label: 'Statut', value: a.status ?? '—'),
          KeyValueRow(label: 'ID distant', value: a.remoteId ?? '—'),
          const Divider(height: 24),
          KeyValueRow(label: 'Créé le', value: _fmtDate(a.createdAt)),
          KeyValueRow(label: 'Mis à jour le', value: _fmtDate(a.updatedAt)),
          KeyValueRow(label: 'Supprimé le', value: _fmtDate(a.deletedAt)),
          KeyValueRow(label: 'Synchronisé le', value: _fmtDate(a.syncAt)),
          KeyValueRow(label: 'Version', value: '${a.version}'),
          const SizedBox(height: 12),
          const Text('ID', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(a.id),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDef) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    onMakeDefault?.call();
                  },
                  icon: const Icon(Icons.star),
                  label: const Text('Définir par défaut'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async => _copyAll(context),
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copier les détails'),
              ),
            ),
            const SizedBox(height: 12),
            if (onShare != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    onShare!.call();
                  },
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('Partager'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  var ok = true;
                  if (confirmHere) {
                    ok = await _confirmDelete(context);
                  }
                  if (!ok) return;
                  try {
                    final repo = ref.read(accountRepoProvider);
                    await repo.softDelete(a.id);
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('Compte supprimé')),
                    );
                    Navigator.of(context).maybePop();
                    onDelete?.call();
                    try {
                      ref.invalidate(accountRepoProvider);
                    } catch (_) {}
                  } catch (e) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(content: Text('Échec de la suppression : $e')),
                    );
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
