// lib/presentation/features/products/product_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/products/repositories/product_repository.dart';
import 'package:money_pulse/presentation/features/products/product_repo_provider.dart';

import 'package:money_pulse/presentation/app/providers.dart'; // categoryRepoProvider
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import 'widgets/product_tile.dart';
import 'widgets/product_form_panel.dart';
import 'widgets/product_delete_panel.dart';
import 'widgets/product_view_panel.dart';
import 'widgets/product_stock_adjust_panel.dart';

// For stock filtering (optional/when used)
import 'package:money_pulse/domain/stock/repositories/stock_level_repository.dart'
    show StockLevelRow;
import 'package:money_pulse/presentation/features/stock/providers/stock_level_repo_provider.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  late final ProductRepository _repo = ref.read(productRepoProvider);
  final _searchCtrl = TextEditingController();
  String _query = '';

  // ---------- Filtres légers & discrets ----------
  _ProductFilters _filters = const _ProductFilters();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() => _query = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Product>> _load() async {
    if (_query.trim().isEmpty) {
      return _repo.findAllActive();
    }
    return _repo.searchActive(_query, limit: 300);
  }

  Future<void> _share(Product p) async {
    final text = [
      'Produit: ${p.name ?? p.code ?? '—'}',
      if ((p.code ?? '').isNotEmpty) 'Code: ${p.code}',
      if ((p.barcode ?? '').isNotEmpty) 'EAN: ${p.barcode}',
      'Prix: ${(p.defaultPrice / 100).toStringAsFixed(0)}',
      'ID: ${p.id}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Détails copiés')));
  }

  Future<void> _openAdjust(Product p) async {
    final changed = await showRightDrawer<bool>(
      context,
      child: ProductStockAdjustPanel(product: p),
      widthFraction: 0.86,
      heightFraction: 0.9,
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stock ajusté.')));
    }
  }

  Future<void> _addOrEdit({Product? existing}) async {
    final categories = await ref.read(categoryRepoProvider).findAllActive();
    if (!mounted) return;

    final res = await showRightDrawer<ProductFormResult?>(
      context,
      child: ProductFormPanel(existing: existing, categories: categories),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    if (res == null) return;

    final now = DateTime.now();
    if (existing == null) {
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
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        syncAt: null,
        version: 0,
        isDirty: 1,
      );
      await _repo.create(p);
    } else {
      final updated = existing.copyWith(
        code: res.code,
        name: res.name,
        description: res.description,
        barcode: res.barcode,
        categoryId: res.categoryId,
        defaultPrice: res.priceCents,
      );
      await _repo.update(updated);
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete(Product p) async {
    if (!mounted) return;
    final ok = await showRightDrawer<bool>(
      context,
      child: ProductDeletePanel(product: p),
      widthFraction: 0.86,
      heightFraction: 0.6,
    );
    if (ok == true) {
      await _repo.softDelete(p.id);
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _view(Product p) async {
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
        onEdit: () async {
          Navigator.of(context).pop();
          await _addOrEdit(existing: p);
        },
        onDelete: () async {
          Navigator.of(context).pop();
          await _confirmDelete(p);
        },
        onShare: () => _share(p),
        onAdjust: () => _openAdjust(p),
      ),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
  }

  // ---------- Stock map (calculé uniquement si filtre stock actif) ----------
  Future<Map<String, int>> _computeStockMap(List<Product> items) async {
    final stockRepo = ref.read(stockLevelRepoProvider);
    final map = <String, int>{}; // productId -> total (onHand - allocated)

    // On s'appuie sur la recherche plein texte du stock repo, par produit.
    // Ce n'est appelé que si filtreStock != ANY pour éviter les surcoûts.
    for (final p in items) {
      final q = (p.code?.trim().isNotEmpty ?? false)
          ? p.code!.trim()
          : (p.name?.trim() ?? '');
      if (q.isEmpty) {
        map[p.id] = 0;
        continue;
      }
      final rows = await stockRepo.search(query: q);
      // On restreint par heuristique: le label doit contenir code ou nom
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

  // ---------- Application locale des filtres ----------
  List<Product> _applyLocalFilters(
    List<Product> base, {
    Map<String, int>? stockByProduct,
  }) {
    final f = _filters;

    bool matchDate(Product p) {
      if (f.dateRange == null) return true;
      final d = f.dateField == _DateField.updated ? p.updatedAt : p.createdAt;
      final start = DateTime(
        f.dateRange!.start.year,
        f.dateRange!.start.month,
        f.dateRange!.start.day,
      );
      final end = DateTime(
        f.dateRange!.end.year,
        f.dateRange!.end.month,
        f.dateRange!.end.day,
        23,
        59,
        59,
        999,
      );
      return (d.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
          d.isBefore(end.add(const Duration(milliseconds: 1))));
    }

    bool matchPrice(Product p) {
      final min = f.minPriceCents;
      final max = f.maxPriceCents;
      if (min != null && p.defaultPrice < min) return false;
      if (max != null && p.defaultPrice > max) return false;
      return true;
    }

    bool matchStock(Product p) {
      if (f.stock == _StockFilter.any) return true;
      final qty = stockByProduct?[p.id];
      if (qty == null) return true; // pas de donnée => ne pas exclure
      if (f.stock == _StockFilter.inStock) return qty > 0;
      if (f.stock == _StockFilter.outOfStock) return qty <= 0;
      return true;
    }

    return base
        .where((p) => matchDate(p) && matchPrice(p) && matchStock(p))
        .toList();
  }

  // ---------- Bottom sheet "Filtres" ----------
  Future<void> _openFiltersSheet() async {
    final res = await showModalBottomSheet<_ProductFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FiltersSheet(initial: _filters),
    );
    if (res != null && mounted) {
      setState(() => _filters = res);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, bc) {
        // Center content on very wide screens
        final maxContentWidth = 980.0;
        final sidePadding = bc.maxWidth > maxContentWidth
            ? (bc.maxWidth - maxContentWidth) / 2
            : 0.0;

        return FutureBuilder<List<Product>>(
          future: _load(),
          builder: (context, snap) {
            final items = snap.data ?? const <Product>[];

            // Stock filter? compute stock map once (light UX: only when needed)
            final needsStock = _filters.stock != _StockFilter.any;
            final stockFuture = needsStock
                ? _computeStockMap(items)
                : Future.value(<String, int>{});

            final body = switch (snap.connectionState) {
              ConnectionState.waiting => const Center(
                child: CircularProgressIndicator(),
              ),
              _ => FutureBuilder<Map<String, int>>(
                future: stockFuture,
                builder: (context, stockSnap) {
                  final stockMap =
                      (stockSnap.connectionState == ConnectionState.done)
                      ? (stockSnap.data ?? const <String, int>{})
                      : null;

                  final filtered = _applyLocalFilters(
                    items,
                    stockByProduct: stockMap,
                  );

                  if (items.isEmpty) {
                    return _EmptySection(onAdd: () => _addOrEdit());
                  }

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: sidePadding),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                      itemCount: filtered.length + 1,
                      separatorBuilder: (_, i) => i == 0
                          ? const SizedBox.shrink()
                          : const Divider(height: 1),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return _HeaderBar(
                            total: items.length,
                            searchCtrl: _searchCtrl,
                            onOpenFilters: _openFiltersSheet,
                            filters: _filters,
                            onClearFilters: () => setState(
                              () => _filters = const _ProductFilters(),
                            ),
                          );
                        }

                        final p = filtered[i - 1];
                        final title = p.name?.isNotEmpty == true
                            ? p.name!
                            : (p.code ?? 'Produit');
                        final sub = [
                          if ((p.code ?? '').isNotEmpty) 'Code: ${p.code}',
                          if ((p.barcode ?? '').isNotEmpty) 'EAN: ${p.barcode}',
                          if ((p.description ?? '').isNotEmpty) p.description!,
                        ].join('  •  ');

                        // Stock badge only if stock filter active (to avoid clutter)
                        final stockBadge = (needsStock && stockMap != null)
                            ? (stockMap[p.id] ?? 0)
                            : null;

                        return ProductTile(
                          title: title,
                          subtitle: sub.isEmpty ? null : sub,
                          priceCents: p.defaultPrice,
                          onTap: () => _view(p),
                          onMenuAction: (action) async {
                            await Future.delayed(Duration.zero);
                            if (!mounted) return;
                            switch (action) {
                              case 'view':
                                await _view(p);
                                break;
                              case 'edit':
                                await _addOrEdit(existing: p);
                                break;
                              case 'adjust':
                                await _openAdjust(p);
                                break;
                              case 'delete':
                                await _confirmDelete(p);
                                break;
                              case 'share':
                                await _share(p);
                                break;
                            }
                          },
                        )._withRightBadge(stockBadge);
                      },
                    ),
                  );
                },
              ),
            };

            return Scaffold(
              appBar: AppBar(
                title: const Text('Produits'),
                actions: [
                  IconButton(
                    tooltip: 'Filtres',
                    onPressed: _openFiltersSheet,
                    icon: const Icon(Icons.filter_list),
                  ),
                  IconButton(
                    tooltip: 'Ajouter',
                    onPressed: () => _addOrEdit(),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _addOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau produit'),
              ),
              body: body,
            );
          },
        );
      },
    );
  }
}

/* ================================== UI pieces ================================== */

class _HeaderBar extends StatelessWidget {
  final int total;
  final TextEditingController searchCtrl;
  final VoidCallback onOpenFilters;
  final _ProductFilters filters;
  final VoidCallback onClearFilters;

  const _HeaderBar({
    required this.total,
    required this.searchCtrl,
    required this.onOpenFilters,
    required this.filters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final pills = <Widget>[
      Chip(
        avatar: const Icon(Icons.inventory_2_outlined, size: 18),
        label: Text('Total: $total'),
      ),
      if (filters.hasAny)
        InputChip(
          avatar: const Icon(Icons.filter_alt, size: 18),
          label: const Text('Filtres actifs'),
          onPressed: onOpenFilters,
          onDeleted: onClearFilters,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Produits', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: pills),
        const SizedBox(height: 12),
        TextField(
          controller: searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher par nom, code ou EAN',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptySection({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 72),
            const SizedBox(height: 12),
            const Text(
              'Aucun produit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ajoutez votre premier produit pour détailler vos achats.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau produit'),
            ),
          ],
        ),
      ),
    );
  }
}

/* ============================== Filters (model + UI) ============================== */

enum _DateField { created, updated }

enum _StockFilter { any, inStock, outOfStock }

class _ProductFilters {
  final _DateField dateField;
  final DateTimeRange? dateRange;
  final int? minPriceCents;
  final int? maxPriceCents;
  final _StockFilter stock;

  const _ProductFilters({
    this.dateField = _DateField.updated,
    this.dateRange,
    this.minPriceCents,
    this.maxPriceCents,
    this.stock = _StockFilter.any,
  });

  bool get hasAny =>
      dateRange != null ||
      minPriceCents != null ||
      maxPriceCents != null ||
      stock != _StockFilter.any;

  _ProductFilters copyWith({
    _DateField? dateField,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    int? minPriceCents,
    bool clearMin = false,
    int? maxPriceCents,
    bool clearMax = false,
    _StockFilter? stock,
  }) {
    return _ProductFilters(
      dateField: dateField ?? this.dateField,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      minPriceCents: clearMin ? null : (minPriceCents ?? this.minPriceCents),
      maxPriceCents: clearMax ? null : (maxPriceCents ?? this.maxPriceCents),
      stock: stock ?? this.stock,
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  final _ProductFilters initial;
  const _FiltersSheet({required this.initial});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late _ProductFilters _f;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _f = widget.initial;
    if (_f.minPriceCents != null) {
      _minCtrl.text = (_f.minPriceCents! ~/ 100).toString();
    }
    if (_f.maxPriceCents != null) {
      _maxCtrl.text = (_f.maxPriceCents! ~/ 100).toString();
    }
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final init =
        _f.dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: init,
    );
    if (picked != null) {
      setState(() => _f = _f.copyWith(dateRange: picked));
    }
  }

  void _applyAndClose() {
    // Price in € fields -> cents
    int? minC;
    int? maxC;
    final minTxt = _minCtrl.text.trim();
    final maxTxt = _maxCtrl.text.trim();
    if (minTxt.isNotEmpty) minC = (int.tryParse(minTxt) ?? 0) * 100;
    if (maxTxt.isNotEmpty) maxC = (int.tryParse(maxTxt) ?? 0) * 100;

    Navigator.of(context).pop(
      _f.copyWith(
        minPriceCents: minC,
        clearMin: minTxt.isEmpty,
        maxPriceCents: maxC,
        clearMax: maxTxt.isEmpty,
      ),
    );
  }

  void _reset() {
    setState(() {
      _f = const _ProductFilters();
      _minCtrl.clear();
      _maxCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Filtres',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.filter_alt_off),
                      label: const Text('Réinitialiser'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Date field & range
                Row(
                  children: [
                    const Text('Date : '),
                    const SizedBox(width: 8),
                    SegmentedButton<_DateField>(
                      segments: const [
                        ButtonSegment(
                          value: _DateField.created,
                          label: Text('Création'),
                          icon: Icon(Icons.event_available),
                        ),
                        ButtonSegment(
                          value: _DateField.updated,
                          label: Text('Mise à jour'),
                          icon: Icon(Icons.update),
                        ),
                      ],
                      selected: {_f.dateField},
                      onSelectionChanged: (s) =>
                          setState(() => _f = _f.copyWith(dateField: s.first)),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.event),
                      label: Text(
                        _f.dateRange == null
                            ? 'Période : Toutes'
                            : '${_fmtDate(_f.dateRange!.start)} → ${_fmtDate(_f.dateRange!.end)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Price min/max
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Prix min (€)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _maxCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Prix max (€)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stock
                Row(
                  children: [
                    const Text('Stock : '),
                    const SizedBox(width: 8),
                    SegmentedButton<_StockFilter>(
                      segments: const [
                        ButtonSegment(
                          value: _StockFilter.any,
                          label: Text('Tous'),
                          icon: Icon(Icons.inventory_2_outlined),
                        ),
                        ButtonSegment(
                          value: _StockFilter.inStock,
                          label: Text('En stock'),
                          icon: Icon(Icons.check_circle_outline),
                        ),
                        ButtonSegment(
                          value: _StockFilter.outOfStock,
                          label: Text('Rupture'),
                          icon: Icon(Icons.remove_circle_outline),
                        ),
                      ],
                      selected: {_f.stock},
                      onSelectionChanged: (s) =>
                          setState(() => _f = _f.copyWith(stock: s.first)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _applyAndClose,
                        icon: const Icon(Icons.check),
                        label: const Text('Appliquer'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Fermer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }
}

/* =========================== Small extension for badge =========================== */

extension on ProductTile {
  /// Optionally show a small stock badge at the end of the tile (without clutter).
  Widget _withRightBadge(int? stock) {
    if (stock == null) return this;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: stock > 0
            ? Colors.green.withOpacity(.12)
            : Colors.red.withOpacity(.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        stock > 0 ? 'Stock: $stock' : 'Rupture',
        style: TextStyle(
          color: stock > 0 ? Colors.green.shade800 : Colors.red.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
    return Stack(
      children: [
        this,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 56.0),
                child: badge,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
