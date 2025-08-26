// Read-only right-drawer to display a StockLevel without exposing raw IDs. Shows labels and quantities.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/stock/entities/stock_level.dart';
import 'providers/stock_level_repo_provider.dart';
import 'package:money_pulse/domain/stock/repositories/stock_level_repository.dart';
import '../../shared/formatters.dart';

class StockLevelViewPanel extends ConsumerWidget {
  final String itemId;
  const StockLevelViewPanel({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(stockLevelRepoProvider);
    return FutureBuilder<StockLevel?>(
      future: repo.findById(itemId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final level = snap.data;
        if (level == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Détail stock')),
            body: const Center(child: Text('Introuvable')),
          );
        }

        return FutureBuilder<List<StockLevelRow>>(
          future: repo.search(query: ''), // to resolve labels
          builder: (context, rowsSnap) {
            final row = rowsSnap.data?.firstWhere(
              (r) => r.id == itemId,
              orElse: () => StockLevelRow(
                id: itemId,
                productLabel: 'Produit',
                companyLabel: 'Société',
                stockOnHand: level.stockOnHand,
                stockAllocated: level.stockAllocated,
                updatedAt: level.updatedAt,
              ),
            );

            final t = Theme.of(context);
            final dispo = level.stockOnHand;
            final allo = level.stockAllocated;
            final net = (dispo - allo);

            return Scaffold(
              appBar: AppBar(
                title: const Text('Détail stock'),
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
                          child: Text(
                            (row?.productLabel.characters.first ?? 'P')
                                .toUpperCase(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row?.productLabel ?? 'Produit',
                                style: t.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                row?.companyLabel ?? 'Société',
                                style: t.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            'Maj ${Formatters.timeHm(level.updatedAt)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Quantités', style: t.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _KV('Disponible', '$dispo'),
                    _KV('Alloué', '$allo'),
                    _KV('Net', '$net'),
                    const SizedBox(height: 16),
                    Text('Metadonnées', style: t.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _KV('Créé le', Formatters.dateFull(level.createdAt)),
                    _KV('Modifié le', Formatters.dateFull(level.updatedAt)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
        children: [
          SizedBox(width: 160, child: Text(k, style: keyStyle)),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
