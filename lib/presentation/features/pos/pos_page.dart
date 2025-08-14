// POS page with improved UI: debounced search, visible active-filter chips, clear-filters buttons, filter badge, refresh, stock display, responsive grid.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/presentation/features/products/product_repo_provider.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'state/pos_cart.dart';
import 'widgets/pos_cart_panel.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/application/usecases/checkout_cart_usecase.dart';
import 'package:money_pulse/presentation/features/stock/providers/stock_level_repo_provider.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

import 'widgets/pos_cart_tile.dart';

class PosFilters {
  final bool inStockOnly;
  final String? categoryId;
  final String? categoryLabel;
  final int? minPriceCents;
  final int? maxPriceCents;
  const PosFilters({
    this.inStockOnly = false,
    this.categoryId,
    this.categoryLabel,
    this.minPriceCents,
    this.maxPriceCents,
  });
  PosFilters copyWith({
    bool? inStockOnly,
    String? categoryId,
    String? categoryLabel,
    int? minPriceCents,
    int? maxPriceCents,
  }) {
    return PosFilters(
      inStockOnly: inStockOnly ?? this.inStockOnly,
      categoryId: categoryId ?? this.categoryId,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      minPriceCents: minPriceCents ?? this.minPriceCents,
      maxPriceCents: maxPriceCents ?? this.maxPriceCents,
    );
  }
}

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
    final map = <String, int>{};
    for (final p in items) {
      final q = (p.code?.trim().isNotEmpty ?? false)
          ? p.code!.trim()
          : (p.name?.trim() ?? '');
      if (q.isEmpty) {
        map[p.id] = 0;
        continue;
      }
      final rows = await stockRepo.search(query: q);
      final relevant = rows.where((r) {
        if ((p.code ?? '').isNotEmpty) {
          return r.productLabel.toLowerCase().contains(p.code!.toLowerCase());
        }
        if ((p.name ?? '').isNotEmpty) {
          return r.productLabel.toLowerCase().contains(p.name!.toLowerCase());
        }
        return true;
      });
      final total = relevant.fold<int>(
        0,
        (prev, e) => prev + (e.stockOnHand - e.stockAllocated),
      );
      map[p.id] = total;
    }
    return map;
  }

  List<Product> _applyInStockOnly(
    List<Product> items,
    Map<String, int> stockByProduct,
  ) {
    if (!_filters.inStockOnly) return items;
    return items.where((p) => (stockByProduct[p.id] ?? 0) > 0).toList();
  }

  Future<void> _openCart() async {
    final db = ref.read(dbProvider);
    final accRepo = ref.read(accountRepoProvider);
    final checkout = CheckoutCartUseCase(db, accRepo);
    await showRightDrawer<bool>(
      context,
      child: PosCartPanel(
        cart: _cart,
        onCheckout: (typeEntry, {description, categoryId, when}) async {
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
          _PosFiltersSheet(initial: _filters, categories: categories),
    );
    if (res != null && mounted) {
      setState(() => _filters = res);
    }
  }

  void _clearFilters() => setState(() => _filters = const PosFilters());

  void _refresh() => setState(() => _reloadTick++);

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
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          if (_hasFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _ActiveFiltersBar(
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
                      final list = _applyInStockOnly(items, stockMap);
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
                                final sub = (p.code ?? '').isNotEmpty
                                    ? 'Code: ${p.code}'
                                    : (p.barcode ?? '');
                                final stockQty = stockMap[p.id] ?? 0;
                                return PosProductTile(
                                  title: title,
                                  subtitle: sub.isEmpty ? null : sub,
                                  priceCents: p.defaultPrice,
                                  stockQty: stockQty,
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

class _ActiveFiltersBar extends StatelessWidget {
  final PosFilters filters;
  final VoidCallback onClearAll;
  final VoidCallback onToggleStock;
  final VoidCallback onClearCategory;
  final VoidCallback onClearMin;
  final VoidCallback onClearMax;

  const _ActiveFiltersBar({
    required this.filters,
    required this.onClearAll,
    required this.onToggleStock,
    required this.onClearCategory,
    required this.onClearMin,
    required this.onClearMax,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (filters.inStockOnly) {
      chips.add(
        FilterChip(
          label: const Text('En stock'),
          selected: true,
          onSelected: (_) => onToggleStock(),
        ),
      );
    }
    if ((filters.categoryId ?? '').isNotEmpty) {
      chips.add(
        InputChip(
          label: Text('Catégorie: ${filters.categoryLabel ?? '—'}'),
          onDeleted: onClearCategory,
        ),
      );
    }
    if (filters.minPriceCents != null) {
      chips.add(
        InputChip(
          label: Text('Prix ≥ ${(filters.minPriceCents! ~/ 100)}'),
          onDeleted: onClearMin,
        ),
      );
    }
    if (filters.maxPriceCents != null) {
      chips.add(
        InputChip(
          label: Text('Prix ≤ ${(filters.maxPriceCents! ~/ 100)}'),
          onDeleted: onClearMax,
        ),
      );
    }
    chips.add(
      ActionChip(
        avatar: const Icon(Icons.filter_alt_off),
        label: const Text('Effacer les filtres'),
        onPressed: onClearAll,
      ),
    );
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _PosFiltersSheet extends StatefulWidget {
  final PosFilters initial;
  final List<Category> categories;
  const _PosFiltersSheet({required this.initial, required this.categories});
  @override
  State<_PosFiltersSheet> createState() => _PosFiltersSheetState();
}

class _PosFiltersSheetState extends State<_PosFiltersSheet> {
  late bool _inStockOnly;
  String? _categoryId;
  String? _categoryLabel;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inStockOnly = widget.initial.inStockOnly;
    _categoryId = widget.initial.categoryId;
    _categoryLabel = widget.initial.categoryLabel;
    if (widget.initial.minPriceCents != null) {
      _minCtrl.text = (widget.initial.minPriceCents! ~/ 100).toString();
    }
    if (widget.initial.maxPriceCents != null) {
      _maxCtrl.text = (widget.initial.maxPriceCents! ~/ 100).toString();
    }
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  int? _toCents(String v) {
    final s = v
        .trim()
        .replaceAll(RegExp(r'[\u00A0\u202F\s]'), '')
        .replaceAll(',', '.');
    if (s.isEmpty) return null;
    final d = double.tryParse(s);
    if (d == null) return null;
    final c = (d * 100).round();
    return c < 0 ? 0 : c;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, ctrl) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Filtres'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Fermer',
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _inStockOnly = false;
                    _categoryId = null;
                    _categoryLabel = null;
                    _minCtrl.clear();
                    _maxCtrl.clear();
                  });
                },
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Effacer'),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                value: _inStockOnly,
                onChanged: (v) => setState(() => _inStockOnly = v),
                title: const Text('En stock uniquement'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _categoryId,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Toutes catégories'),
                  ),
                  ...widget.categories.map((c) {
                    return DropdownMenuItem(value: c.id, child: Text(c.code));
                  }),
                ],
                onChanged: (v) {
                  setState(() {
                    _categoryId = v;
                    _categoryLabel = widget.categories
                        .firstWhere(
                          (e) => e.id == v,
                          orElse: () => Category(
                            id: '',
                            code: '—',
                            description: null,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                            deletedAt: null,
                            remoteId: null,
                            syncAt: null,
                            version: 0,
                            isDirty: false,
                          ),
                        )
                        .code;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Prix min',
                        hintText: 'ex: 1000',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Prix max',
                        hintText: 'ex: 5000',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _inStockOnly = false;
                          _categoryId = null;
                          _categoryLabel = null;
                          _minCtrl.clear();
                          _maxCtrl.clear();
                        });
                      },
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final minC = _toCents(_minCtrl.text);
                        final maxC = _toCents(_maxCtrl.text);
                        final out = PosFilters(
                          inStockOnly: _inStockOnly,
                          categoryId: _categoryId,
                          categoryLabel: _categoryLabel,
                          minPriceCents: minC,
                          maxPriceCents: maxC,
                        );
                        Navigator.pop(context, out);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
