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

import '../stock/providers/stock_level_repo_provider.dart'; // stockLevelRepoProvider
import 'widgets/header_bar.dart';
import 'filters/product_filters.dart';
import 'filters/filters_sheet.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  late final ProductRepository _repo = ref.read(productRepoProvider);
  final _searchCtrl = TextEditingController();
  String _query = '';
  ProductFilters _filters = const ProductFilters();

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

  Future<Map<String, int>> _computeStockMap(List<Product> items) async {
    final stockRepo = ref.read(stockLevelRepoProvider);
    final map = <String, int>{}; // productId -> total (onHand - allocated)

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

  List<Product> _applyLocalFilters(
    List<Product> base, {
    Map<String, int>? stockByProduct,
  }) {
    final f = _filters;

    bool matchDate(Product p) {
      if (f.dateRange == null) return true;
      final d = f.dateField == DateField.updated ? p.updatedAt : p.createdAt;
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
      if (f.stock == StockFilter.any) return true;
      final qty = stockByProduct?[p.id];
      if (qty == null) return true; // pas de donnée => ne pas exclure
      if (f.stock == StockFilter.inStock) return qty > 0;
      if (f.stock == StockFilter.outOfStock) return qty <= 0;
      return true;
    }

    return base
        .where((p) => matchDate(p) && matchPrice(p) && matchStock(p))
        .toList();
  }

  Future<void> _openFiltersSheet() async {
    final res = await showModalBottomSheet<ProductFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FiltersSheet(initial: _filters),
    );
    if (res != null && mounted) {
      setState(() => _filters = res);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, bc) {
        final maxContentWidth = 980.0;
        final sidePadding = bc.maxWidth > maxContentWidth
            ? (bc.maxWidth - maxContentWidth) / 2
            : 0.0;

        return FutureBuilder<List<Product>>(
          future: _load(),
          builder: (context, snap) {
            final items = snap.data ?? const <Product>[];

            final needsStock = _filters.stock != StockFilter.any;
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
                          return HeaderBar(
                            total: items.length,
                            searchCtrl: _searchCtrl,
                            filters: _filters,
                            onOpenFilters: _openFiltersSheet,
                            onClearFilters: () => setState(
                              () => _filters = const ProductFilters(),
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

                        final stockQty = (needsStock && stockMap != null)
                            ? (stockMap[p.id] ?? 0)
                            : null;

                        return ProductTile(
                          title: title,
                          subtitle: sub.isEmpty ? null : sub,
                          priceCents: p.defaultPrice,
                          stockQty: stockQty,
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
                        );
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
