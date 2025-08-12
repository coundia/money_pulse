import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/presentation/features/products/product_repo_provider.dart';

import '../../../application/usecases/lib/presentation/features/pos/widgets/pos_product_tile.dart';
import 'state/pos_cart.dart';

import 'widgets/pos_cart_panel.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/application/usecases/checkout_cart_usecase.dart';

class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final _cart = PosCart();
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() => _query = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _cart.dispose();
    super.dispose();
  }

  Future<List<Product>> _load() {
    final repo = ref.read(productRepoProvider);
    if (_query.isEmpty) return repo.findAllActive();
    return repo.searchActive(_query, limit: 300);
  }

  String _money(int c) => (c ~/ 100).toString();

  Future<void> _openCart() async {
    final db = ref.read(dbProvider);
    final accRepo = ref.read(accountRepoProvider);
    final checkout = CheckoutCartUseCase(db, accRepo);

    await showRightDrawer<bool>(
      context,
      child: PosCartPanel(
        cart: _cart,
        onCheckout: (typeEntry, {description, categoryId, when}) async {
          // Build line inputs from cart snapshot
          final snap = _cart.snapshot();
          final lines = snap.values
              .map(
                (it) => {
                  'productId': it.productId,
                  'label': it.label,
                  'quantity': it.quantity,
                  'unitPrice': it.unitPrice,
                },
              )
              .toList();

          await checkout.execute(
            typeEntry: typeEntry,
            description: description,
            categoryId: categoryId,
            when: when,
            lines: lines,
          );

          // refresh global balance & tx list
          await ref.read(balanceProvider.notifier).load();
          await ref.read(transactionsProvider.notifier).load();

          _cart.clear();
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Vente enregistrée')));
        },
      ),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    setState(() {}); // to refresh bottom bar
  }

  @override
  Widget build(BuildContext context) {
    final total = _cart.total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point de vente'),
        actions: [
          IconButton(
            tooltip: 'Panier',
            onPressed: _cart.isEmpty ? null : _openCart,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined),
                if (_cart.countLines > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: CircleAvatar(
                      radius: 8,
                      child: Text(
                        _cart.countLines.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, code, EAN)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _load(),
              builder: (context, snap) {
                final items = snap.data ?? const <Product>[];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (items.isEmpty) {
                  return const Center(child: Text('Aucun produit'));
                }
                final cols = MediaQuery.of(context).size.width ~/ 180;
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols.clamp(2, 6),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: .95,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final p = items[i];
                    final title = (p.name?.isNotEmpty ?? false)
                        ? p.name!
                        : (p.code ?? 'Produit');
                    final sub = (p.code ?? '').isNotEmpty
                        ? 'Code: ${p.code}'
                        : (p.barcode ?? '');
                    return PosProductTile(
                      title: title,
                      subtitle: sub.isEmpty ? null : sub,
                      priceCents: p.defaultPrice,
                      onTap: () {
                        _cart.addProduct(p, qty: 1);
                        setState(() {});
                      },
                      onLongPress: () async {
                        // Quick quantity chooser
                        int qty = 1;
                        await showRightDrawer<void>(
                          context,
                          child: Scaffold(
                            appBar: AppBar(
                              title: Text(title),
                              leading: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            body: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Quantité'),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          if (qty > 1) {
                                            qty--;
                                            setState(() {});
                                          }
                                        },
                                        icon: const Icon(Icons.remove),
                                      ),
                                      Text(
                                        '$qty',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineSmall,
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          qty++;
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.add),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: () {
                                      _cart.addProduct(p, qty: qty);
                                      Navigator.pop(context);
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.add_shopping_cart),
                                    label: const Text('Ajouter'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          widthFraction: 0.86,
                          heightFraction: 0.6,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cart.isEmpty
                      ? null
                      : () => setState(() => _cart.clear()),
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Vider'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _cart.isEmpty ? null : _openCart,
                  icon: const Icon(Icons.point_of_sale),
                  label: Text('Encaisser • ${_money(total)}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
