import 'package:flutter/material.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_form_sheet.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import '../transaction_quick_add_sheet.dart';
import 'transaction_detail_view.dart';

class TransactionTile extends StatelessWidget {
  final TransactionEntry entry;
  final Future<void> Function() onDeleted;
  final Future<void> Function() onUpdated;
  final Future<void> Function(TransactionEntry entry)? onSync;

  const TransactionTile({
    super.key,
    required this.entry,
    required this.onDeleted,
    required this.onUpdated,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final isDebit = entry.typeEntry == 'DEBIT';
    final sign = isDebit ? '-' : '+';
    final amount = Formatters.amountFromCents(entry.amount);
    final time = Formatters.timeHm(entry.dateTransaction);
    final color = isDebit ? Colors.red : Colors.green;

    return Dismissible(
      key: ValueKey('txn-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: _buildSwipeBg(context, alignStart: true),
      secondaryBackground: _buildSwipeBg(context, alignStart: false),

      // 🔒 Intercepter le swipe AVANT suppression
      confirmDismiss: (direction) async {
        final ok = await _confirmDelete(context);
        if (!ok) return false; // Annule → la tuile reste

        await onDeleted(); // Supprime réellement (repo + refresh)
        return false; // Empêche Dismissible de retirer l’item
      },

      // ❌ Pas de onDismissed – on gère tout dans confirmDismiss
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(isDebit ? Icons.south : Icons.north, color: color),
        ),
        title: Text(
          entry.description ?? entry.code ?? 'Transaction',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(time),
        trailing: Text(
          '$sign$amount',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        onTap: () async {
          final ok = await showRightDrawer<bool>(
            context,
            child: TransactionDetailView(entry: entry),
            widthFraction: 0.86,
            heightFraction: 0.96,
          );
          if (ok == true) await onUpdated();
        },
        onLongPress: () => _openContextMenu(context),
      ),
    );
  }

  // ————————————————— UI helpers —————————————————

  static Widget _buildSwipeBg(
    BuildContext context, {
    required bool alignStart,
  }) {
    final danger = Theme.of(context).colorScheme.error;
    final child = Row(
      mainAxisAlignment: alignStart
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        if (alignStart) const SizedBox(width: 16),
        Icon(Icons.delete_outline, color: Colors.white),
        const SizedBox(width: 8),
        const Text('Supprimer', style: TextStyle(color: Colors.white)),
        if (!alignStart) const SizedBox(width: 16),
      ],
    );
    return Container(
      color: danger,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: child,
    );
  }

  static Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
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
        ) ??
        false;
  }

  Future<void> _openContextMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Voir'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await showRightDrawer<void>(
                    context,
                    child: TransactionDetailView(entry: entry),
                    widthFraction: 0.86,
                    heightFraction: 0.96,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await showRightDrawer<bool>(
                    context,
                    child: TransactionFormSheet(entry: entry),
                    widthFraction: 0.86,
                    heightFraction: 0.96,
                  );
                  if (ok == true) await onUpdated();
                },
              ),
              ListTile(
                leading: const Icon(Icons.sync_outlined),
                title: const Text('Synchroniser'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (onSync != null) {
                    await onSync!(entry);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Synchronisation indisponible'),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Supprimer'),
                textColor: Colors.red,
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await _confirmDelete(context);
                  if (ok) await onDeleted();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
