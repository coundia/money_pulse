/* Small UI action to trigger syncAll() with French labels and feedback. */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/sync/sync_service_provider.dart';

class SyncNowButton extends ConsumerStatefulWidget {
  const SyncNowButton({super.key});
  @override
  ConsumerState<SyncNowButton> createState() => _SyncNowButtonState();
}

class _SyncNowButtonState extends ConsumerState<SyncNowButton> {
  bool _busy = false;
  String? _result;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _busy
          ? null
          : () async {
              setState(() {
                _busy = true;
                _result = null;
              });
              try {
                final s = await syncAllTables(ref);
                setState(() {
                  _result =
                      'Catégories ${s.categories} • Comptes ${s.accounts} • Transactions ${s.transactions} • Unités ${s.units} • Produits ${s.products} • Articles ${s.items} • Sociétés ${s.companies} • Clients ${s.customers} • Dettes ${s.debts} • Stocks ${s.stockLevels} • Mouvements ${s.stockMovements}';
                });
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(_result!)));
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Échec de la synchronisation'),
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _busy = false;
                  });
                }
              }
            },
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
      label: Text(_result ?? 'Synchroniser maintenant'),
    );
  }
}
