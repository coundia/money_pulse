import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/features/transactions/providers/transaction_list_providers.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_form_sheet.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

class TransactionDetailView extends ConsumerWidget {
  final TransactionEntry entry;

  const TransactionDetailView({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDebit = entry.typeEntry == 'DEBIT';
    final sign = isDebit ? '-' : '+';
    final amount = NumberFormat.decimalPattern().format(entry.amount / 100);
    final dateLabel = DateFormat.yMMMMEEEEd().add_Hm().format(
      entry.dateTransaction,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la transaction'),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final ok = await showRightDrawer<bool>(
                context,
                child: TransactionFormSheet(entry: entry),
                widthFraction: 0.86,
                heightFraction: 0.96,
              );
              if (ok == true) {
                await ref.read(transactionsProvider.notifier).load();
                await ref.read(balanceProvider.notifier).load();
                ref.invalidate(transactionListItemsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaction mise à jour')),
                  );
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Confirmer la suppression'),
                  content: const Text('Supprimer cette transaction ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx, false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(dCtx, true),
                      child: const Text('Supprimer'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(transactionRepoProvider).softDelete(entry.id);
                await ref.read(transactionsProvider.notifier).load();
                await ref.read(balanceProvider.notifier).load();
                ref.invalidate(transactionListItemsProvider);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaction supprimée')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Montant'),
            subtitle: Text('$sign$amount'),
          ),
          ListTile(
            title: const Text('Type'),
            subtitle: Text(isDebit ? 'Dépense' : 'Revenu'),
          ),
          ListTile(
            title: const Text('Date et heure'),
            subtitle: Text(dateLabel),
          ),
          ListTile(
            title: const Text('Description'),
            subtitle: Text(entry.description ?? '—'),
          ),
          ListTile(
            title: const Text('Code'),
            subtitle: Text(entry.code ?? '—'),
          ),
          ListTile(title: const Text('Identifiant'), subtitle: Text(entry.id)),
        ],
      ),
    );
  }
}
