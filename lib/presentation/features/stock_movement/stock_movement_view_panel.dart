/// Read-only panel to display a StockMovement inside the right drawer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import '../../../domain/stock/entities/stock_movement.dart';
import 'providers/stock_movement_repo_provider.dart';
import '../../../domain/stock/repositories/stock_movement_repository.dart';

class StockMovementViewPanel extends ConsumerWidget {
  final String itemId;
  const StockMovementViewPanel({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(stockMovementRepoProvider);
    return FutureBuilder<_Vm>(
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
            appBar: AppBar(title: const Text('Mouvement de stock')),
            body: const Center(child: Text('Introuvable')),
          );
        }
        final m = vm.item!;
        return Scaffold(
          appBar: AppBar(title: const Text('Mouvement de stock')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _kv('Produit', vm.productLabel ?? m.productVariantId),
              _kv('Société', vm.companyLabel ?? m.companyId),
              _kv('Type', m.type),
              _kv('Quantité', '${m.quantity}'),
              _kv('Ligne commande', m.orderLineId ?? '—'),
              _kv('Créé le', Formatters.dateFull(m.createdAt)),
              _kv('Mis à jour le', Formatters.dateFull(m.updatedAt)),
              _kv('Discriminateur', m.discriminator ?? '—'),
              _kv('ID', m.id?.toString() ?? '—'),
            ],
          ),
        );
      },
    );
  }

  Future<_Vm> _load(StockMovementRepository repo, String id) async {
    final item = await repo.findById(id);
    if (item == null) return const _Vm(null, null, null);
    final prods = await repo.listProductVariants(query: '');
    final comps = await repo.listCompanies(query: '');
    final p = prods.firstWhere(
      (e) => (e['id']?.toString() ?? '') == item.productVariantId,
      orElse: () => {},
    );
    final c = comps.firstWhere(
      (e) => (e['id']?.toString() ?? '') == item.companyId,
      orElse: () => {},
    );
    return _Vm(item, p['label'] as String?, c['label'] as String?);
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _Vm {
  final StockMovement? item;
  final String? productLabel;
  final String? companyLabel;
  const _Vm(this.item, this.productLabel, this.companyLabel);
}
