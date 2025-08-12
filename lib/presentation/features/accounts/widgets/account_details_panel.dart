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

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            tooltip: 'Copier les détails',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: onShare == null
                ? null
                : () {
                    Navigator.of(context).maybePop();
                    onShare!.call();
                  },
          ),
          TextButton(
            onPressed: onEdit == null
                ? null
                : () {
                    Navigator.of(context).maybePop();
                    onEdit!.call();
                  },
            child: const Text('Modifier'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _kv('Code', a.code ?? '—'),
          _kv('Description', a.description ?? '—'),
          _kv('Devise', a.currency ?? '—'),
          const SizedBox(height: 8),
          _kv('Solde', _fmtMoney(a.balance, a.currency)),
          _kv('Solde précédent', _fmtMoney(a.balancePrev, a.currency)),
          _kv('Solde bloqué', _fmtMoney(a.balanceBlocked, a.currency)),
          const Divider(height: 24),
          _kv('Par défaut', isDef ? 'Oui' : 'Non'),
          _kv('Statut', a.status ?? '—'),
          _kv('ID distant', a.remoteId ?? '—'),
          const Divider(height: 24),
          _kv('Créé le', _fmtDate(a.createdAt)),
          _kv('Mis à jour le', _fmtDate(a.updatedAt)),
          _kv('Supprimé le', _fmtDate(a.deletedAt)),
          _kv('Synchronisé le', _fmtDate(a.syncAt)),
          _kv('Version', '${a.version}'),
          const SizedBox(height: 12),
          const Text('ID', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(a.id),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            if (!isDef) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMakeDefault == null
                      ? null
                      : () {
                          Navigator.of(context).maybePop();
                          onMakeDefault!.call();
                        },
                  icon: const Icon(Icons.star),
                  label: const Text('Défaut'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextButton.icon(
                onPressed: onDelete == null
                    ? null
                    : () {
                        Navigator.of(context).maybePop();
                        onDelete!.call();
                      },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
