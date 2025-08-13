// Right drawer panel to display StockLevel details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'providers/stock_level_repo_provider.dart';
import 'package:money_pulse/domain/stock/entities/stock_level.dart';
import 'package:money_pulse/domain/stock/repositories/stock_level_repository.dart';

class StockLevelViewPanel extends ConsumerWidget {
  final String itemId;
  const StockLevelViewPanel({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(stockLevelRepoProvider);
    return FutureBuilder<StockLevel?>(
      future: repo.findById(itemId),
      builder: (context, snap) {
        final theme = Theme.of(context);
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final item = snap.data;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Détail stock')),
            body: const Center(child: Text('Introuvable')),
          );
        }
        final nf = NumberFormat.decimalPattern();
        return Scaffold(
          appBar: AppBar(title: const Text('Détail stock')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  _kv('Produit (variant ID)', item.productVariantId.toString()),
                  _kv('Entreprise', item.companyId),
                  _kv('Stock disponible', nf.format(item.stockOnHand)),
                  _kv('Stock alloué', nf.format(item.stockAllocated)),
                  _kv(
                    'Créé le',
                    DateFormat.yMMMMEEEEd().add_Hm().format(item.createdAt),
                  ),
                  _kv(
                    'Mis à jour',
                    DateFormat.yMMMMEEEEd().add_Hm().format(item.updatedAt),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(flex: 3, child: Text(v)),
        ],
      ),
    );
  }
}
