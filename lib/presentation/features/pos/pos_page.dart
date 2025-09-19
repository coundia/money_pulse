// POS page orchestrating grid, search, filters, actions, and product drawers with added mark and quantity on tiles.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/presentation/features/products/product_repo_provider.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import '../../../domain/debts/repositories/debt_repository.dart';
import '../debts/debt_repo_provider.dart';
import 'state/pos_cart.dart';
import 'widgets/pos_cart_panel.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/application/usecases/checkout_cart_usecase.dart';
import 'package:money_pulse/presentation/features/stock/providers/stock_level_repo_provider.dart';

import 'widgets/pos_cart_tile.dart';
import 'filters/pos_filters.dart';
import 'filters/pos_active_filters_bar.dart';
import 'filters/pos_filters_sheet.dart';
import 'utils/pos_stock_utils.dart';

import 'package:money_pulse/presentation/features/products/widgets/product_form_panel.dart';
import 'package:money_pulse/presentation/features/products/product_list_page.dart';
import 'package:money_pulse/presentation/features/products/widgets/product_view_panel.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});
  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final _cart = PosCart();
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;
  PosFilters _filters = const PosFilters();
  int _reloadTick = 0;

  bool get _hasFilters =>
      _filters.inStockOnly ||
      _filters.categoryId != null ||
      _filters.minPriceCents != null ||
      _filters.maxPriceCents != null;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        setState(() => _query = _searchCtrl.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Product>> _load(int tick) async {
    final repo = ref.read(productRepoProvider);
    final base = _query.isEmpty
        ? await repo.findAllActive()
        : await repo.searchActive(_query, limit: 300);
    base.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (!_hasFilters) return base;
    return base.where((p) {
      if (_filters.categoryId != null && p.categoryId != _filters.categoryId) {
        return false;
      }
      if (_filters.minPriceCents != null &&
          p.defaultPrice < _filters.minPriceCents!) {
        return false;
      }
      if (_filters.maxPriceCents != null &&
          p.defaultPrice > _filters.maxPriceCents!) {
        return false;
      }
      return true;
    }).toList();
  }

  String _money(int c) => Formatters.amountFromCents(c);

  Future<Map<String, int>> _computeStockMap(List<Product> items) async {
    final stockRepo = ref.read(stockLevelRepoProvider);
    return computeStockMap(stockRepo, items);
  }

  Future<void> _openCart() async {
    final db = ref.read(dbProvider);
    final accRepo = ref.read(accountRepoProvider);
    final debtRepo = ref.read(debtRepoProvider) as DebtRepository;
    final checkout = CheckoutCartUseCase(db, accRepo, debtRepo);
    await showRightDrawer<bool>(
      context,
      child: PosCartPanel(
        cart: _cart,
        onCheckout:
            (typeEntry, {description, categoryId, customerId, when}) async {
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
                customerId: customerId,
                when: when,
                lines: lines,
              );

              await ref.read(balanceProvider.notifier).load();
              await ref.read(transactionsProvider.notifier).load();
              _cart.clear();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vente enregistrée')),
              );
            },
      ),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    if (mounted) setState(() {});
  }

  Future<void> _openFiltersSheet() async {
    final categories = await ref.read(categoryRepoProvider).findAllActive();
    if (!mounted) return;
    final res = await showModalBottomSheet<PosFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          PosFiltersSheet(initial: _filters, categories: categories),
    );
    if (res != null && mounted) {
      setState(() => _filters = res);
    }
  }

  void _clearFilters() => setState(() => _filters = const PosFilters());
  void _refresh() => setState(() => _reloadTick++);

  Future<void> _addProductFromPos() async {
    final categories = await ref.read(categoryRepoProvider).findAllActive();
    if (!mounted) return;
    final res = await showRightDrawer<ProductFormResult?>(
      context,
      child: ProductFormPanel(categories: categories),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    if (res == null) return;

    final repo = ref.read(productRepoProvider);
    final now = DateTime.now();
    final p = Product(
      id: const Uuid().v4(),
      remoteId: null,
      code: res.code,
      name: res.name,
      description: res.description,
      barcode: res.barcode,
      unitId: null,
      categoryId: res.categoryId,
      defaultPrice: res.priceCents,
      purchasePrice: res.purchasePriceCents,
      statuses: res.status,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncAt: null,
      version: 0,
      isDirty: 1,
    );
    await repo.create(p);
    if (!mounted) return;
    setState(() => _reloadTick++);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Produit créé')));
  }

  Future<void> _openProductList() async {
    await showRightDrawer<void>(
      context,
      child: const ProductListPage(),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    if (!mounted) return;
    setState(() => _reloadTick++);
  }

  Future<void> _viewProduct(Product p) async {
    String? catLabel;
    if (p.categoryId != null) {
      final cat = await ref.read(categoryRepoProvider).findById(p.categoryId!);
      catLabel = cat?.code;
    }
    if (!mounted) return;
    await showRightDrawer<void>(
      context,
      child: ProductViewPanel(
        product: p,
        categoryLabel: catLabel,
        marketplaceBaseUri: '',
      ),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _cart.total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point de vente'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Filtres',
                onPressed: _openFiltersSheet,
                icon: const Icon(Icons.filter_list),
              ),
              if (_hasFilters)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          if (_hasFilters)
            IconButton(
              tooltip: 'Effacer les filtres',
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off),
            ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (v) async {
              switch (v) {
                case 'list':
                  await _openProductList();
                  break;
                case 'new':
                  await _addProductFromPos();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'list',
                child: ListTile(
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text('Lister les produits'),
                ),
              ),
              PopupMenuItem(
                value: 'new',
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('Créer un produit'),
                ),
              ),
            ],
          ),
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
                hintText: 'Rechercher (nom produit)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          if (_hasFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: PosActiveFiltersBar(
                filters: _filters,
                onClearAll: _clearFilters,
                onToggleStock: () => setState(
                  () => _filters = _filters.copyWith(
                    inStockOnly: !_filters.inStockOnly,
                  ),
                ),
                onClearCategory: () => setState(
                  () => _filters = _filters.copyWith(
                    categoryId: null,
                    categoryLabel: null,
                  ),
                ),
                onClearMin: () => setState(
                  () => _filters = _filters.copyWith(minPriceCents: null),
                ),
                onClearMax: () => setState(
                  () => _filters = _filters.copyWith(maxPriceCents: null),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: FutureBuilder<List<Product>>(
                key: ValueKey(_reloadTick),
                future: _load(_reloadTick),
                builder: (context, snap) {
                  final items = snap.data ?? const <Product>[];
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (items.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('Aucun produit')),
                      ],
                    );
                  }
                  final cols =
                      (MediaQuery.of(context).size.width ~/ 180).clamp(2, 6)
                          as int;
                  final stockFuture = _computeStockMap(items);

                  return FutureBuilder<Map<String, int>>(
                    future: stockFuture,
                    builder: (context, stockSnap) {
                      final stockMap = stockSnap.data ?? const <String, int>{};
                      final list = applyInStockOnly(
                        items: items,
                        stockByProduct: stockMap,
                        inStockOnly: _filters.inStockOnly,
                      );

                      final infoBar = Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                        child: Row(
                          children: [
                            Chip(
                              avatar: const Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                              ),
                              label: Text('Total: ${items.length}'),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              avatar: const Icon(
                                Icons.filter_alt_outlined,
                                size: 18,
                              ),
                              label: Text('Affichés: ${list.length}'),
                            ),
                          ],
                        ),
                      );

                      final cartSnap = _cart.snapshot();

                      return Column(
                        children: [
                          infoBar,
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                8,
                                12,
                                100,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: .95,
                                  ),
                              itemCount: list.length,
                              itemBuilder: (_, i) {
                                final p = list[i];
                                final title = (p.name?.isNotEmpty ?? false)
                                    ? p.name!
                                    : (p.code ?? 'Produit');
                                final subtitle =
                                    (p.description ?? '').trim().isEmpty
                                    ? null
                                    : p.description!.trim();
                                final stockQty = stockMap[p.id] ?? 0;
                                final addedQty = cartSnap[p.id]?.quantity ?? 0;

                                return PosProductTile(
                                  title: title,
                                  subtitle: subtitle,
                                  priceCents: p.defaultPrice,
                                  stockQty: stockQty,
                                  isAdded: addedQty > 0,
                                  addedQty: addedQty,
                                  onTap: () {
                                    _cart.addProduct(p, qty: 1);
                                    setState(() {});
                                  },
                                  onLongPress: () async {
                                    int qty = 1;
                                    await showRightDrawer<void>(
                                      context,
                                      child: StatefulBuilder(
                                        builder: (context, setLocal) {
                                          return Scaffold(
                                            appBar: AppBar(
                                              title: Text(title),
                                              leading: IconButton(
                                                icon: const Icon(Icons.close),
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                              ),
                                            ),
                                            body: Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text('Quantité'),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        onPressed: () {
                                                          if (qty > 1) {
                                                            qty--;
                                                            setLocal(() {});
                                                          }
                                                        },
                                                        icon: const Icon(
                                                          Icons.remove,
                                                        ),
                                                      ),
                                                      Text(
                                                        '$qty',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headlineSmall,
                                                      ),
                                                      IconButton(
                                                        onPressed: () {
                                                          qty++;
                                                          setLocal(() {});
                                                        },
                                                        icon: const Icon(
                                                          Icons.add,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 16),
                                                  FilledButton.icon(
                                                    onPressed: () {
                                                      _cart.addProduct(
                                                        p,
                                                        qty: qty,
                                                      );
                                                      Navigator.pop(context);
                                                      if (mounted)
                                                        setState(() {});
                                                    },
                                                    icon: const Icon(
                                                      Icons.add_shopping_cart,
                                                    ),
                                                    label: const Text(
                                                      'Ajouter',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      widthFraction: 0.86,
                                      heightFraction: 0.6,
                                    );
                                  },
                                  onMenuAction: (action) async {
                                    if (action == 'add1') {
                                      _cart.addProduct(p, qty: 1);
                                      if (mounted) setState(() {});
                                    } else if (action == 'qty') {
                                      int qty = 1;
                                      await showRightDrawer<void>(
                                        context,
                                        child: StatefulBuilder(
                                          builder: (context, setLocal) {
                                            return Scaffold(
                                              appBar: AppBar(
                                                title: Text(title),
                                                leading: IconButton(
                                                  icon: const Icon(Icons.close),
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                ),
                                              ),
                                              body: Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Text('Quantité'),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        IconButton(
                                                          onPressed: () {
                                                            if (qty > 1) {
                                                              qty--;
                                                              setLocal(() {});
                                                            }
                                                          },
                                                          icon: const Icon(
                                                            Icons.remove,
                                                          ),
                                                        ),
                                                        Text(
                                                          '$qty',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .headlineSmall,
                                                        ),
                                                        IconButton(
                                                          onPressed: () {
                                                            qty++;
                                                            setLocal(() {});
                                                          },
                                                          icon: const Icon(
                                                            Icons.add,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 16),
                                                    FilledButton.icon(
                                                      onPressed: () {
                                                        _cart.addProduct(
                                                          p,
                                                          qty: qty,
                                                        );
                                                        Navigator.pop(context);
                                                        if (mounted)
                                                          setState(() {});
                                                      },
                                                      icon: const Icon(
                                                        Icons.add_shopping_cart,
                                                      ),
                                                      label: const Text(
                                                        'Ajouter',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        widthFraction: 0.86,
                                        heightFraction: 0.6,
                                      );
                                    } else if (action == 'details') {
                                      await _viewProduct(p);
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
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
