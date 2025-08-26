// Read-only right-drawer for a stock movement without exposing raw IDs in UI.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/stock_movement_repo_provider.dart';
import '../../../domain/stock/repositories/stock_movement_repository.dart';
import '../../shared/formatters.dart';

class StockMovementViewPanel extends ConsumerWidget {
  final String itemId;
  const StockMovementViewPanel({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(stockMovementRepoProvider);
    return FutureBuilder<StockMovementRow?>(
      future: repo.findRowById(itemId),
      builder: (context, snap) {
        final theme = Theme.of(context);
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final row = snap.data;
        if (row == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Détail mouvement')),
            body: const Center(child: Text('Introuvable')),
          );
        }

        final typeLabels = const {
          'IN': 'Entrée',
          'OUT': 'Sortie',
          'ALLOCATE': 'Allocation',
          'RELEASE': 'Libération',
          'ADJUST': 'Ajustement',
        };
        final typeColor = _typeColor(context, row.type);
        final pu = Formatters.amountFromCents(row.unitPriceCents);
        final tot = Formatters.amountFromCents(row.totalCents);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Détail mouvement'),
            leading: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: typeColor.withOpacity(0.12),
                      foregroundColor: typeColor,
                      child: Text(row.type.substring(0, 1)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.productLabel,
                            style: theme.textTheme.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            row.companyLabel,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(
                      text: typeLabels[row.type] ?? row.type,
                      color: typeColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _ChipIcon(text: 'Type', icon: Icons.compare_arrows),
                    _ChipIcon(text: 'Mouvement', icon: Icons.move_down),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Détails', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _KV('Produit', row.productLabel),
                _KV('Société', row.companyLabel),
                _KV('Type', typeLabels[row.type] ?? row.type),
                _KV('Quantité', '${row.quantity}'),
                _KV('Prix unitaire', pu),
                _KV('Total', tot),
                _KV('Créé le', Formatters.dateFull(row.createdAt)),
              ],
            ),
          ),
        );
      },
    );
  }

  static Color _typeColor(BuildContext ctx, String type) {
    final cs = Theme.of(ctx).colorScheme;
    switch (type) {
      case 'IN':
        return cs.primary;
      case 'OUT':
        return cs.error;
      case 'ALLOCATE':
        return cs.tertiary;
      case 'RELEASE':
        return cs.secondary;
      case 'ADJUST':
        return cs.outline;
      default:
        return cs.onSurfaceVariant;
    }
  }
}

class _KV extends StatelessWidget {
  final String k, v;
  const _KV(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    final keyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 160, child: Text(k, style: keyStyle)),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _ChipIcon extends StatelessWidget {
  final String text;
  final IconData icon;
  const _ChipIcon({required this.text, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(text));
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
      ),
    );
  }
}
