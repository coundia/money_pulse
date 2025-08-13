/// Right drawer panel to display StockLevel details with resolved product/company labels.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'providers/stock_level_repo_provider.dart';
import 'package:money_pulse/domain/stock/entities/stock_level.dart';
import 'package:money_pulse/domain/stock/repositories/stock_level_repository.dart';

class StockLevelViewPanel extends ConsumerWidget {
  final String itemId;
  const StockLevelViewPanel({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(stockLevelRepoProvider);
    return FutureBuilder<_ViewVm>(
      future: _load(repo, itemId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final vm = snap.data;
        if (vm == null || vm.item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Détail stock')),
            body: const Center(child: Text('Introuvable')),
          );
        }
        final item = vm.item!;
        return Scaffold(
          appBar: AppBar(title: const Text('Détail stock')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  _kv('Produit', vm.productLabel ?? item.productVariantId),
                  _kv('Société', vm.companyLabel ?? item.companyId),
                  _kv(
                    'Stock disponible',
                    Formatters.amountFromCents(item.stockOnHand * 100),
                  ),
                  _kv(
                    'Stock alloué',
                    Formatters.amountFromCents(item.stockAllocated * 100),
                  ),
                  _kv('Créé le', Formatters.dateFull(item.createdAt)),
                  _kv('Mis à jour le', Formatters.dateFull(item.updatedAt)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<_ViewVm> _load(StockLevelRepository repo, String id) async {
    final sl = await repo.findById(id);
    if (sl == null) return const _ViewVm(null, null, null);
    String? pLabel;
    String? cLabel;
    final prods = await repo.listProductVariants(query: '');
    final comps = await repo.listCompanies(query: '');
    final p = prods.firstWhere(
      (e) => (e['id']?.toString() ?? '') == sl.productVariantId,
      orElse: () => {},
    );
    final c = comps.firstWhere(
      (e) => (e['id']?.toString() ?? '') == sl.companyId,
      orElse: () => {},
    );
    pLabel = (p['label'] as String?) ?? pLabel;
    cLabel = (c['label'] as String?) ?? cLabel;
    return _ViewVm(sl, pLabel, cLabel);
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

class _ViewVm {
  final StockLevel? item;
  final String? productLabel;
  final String? companyLabel;
  const _ViewVm(this.item, this.productLabel, this.companyLabel);
}
