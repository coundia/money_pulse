// Orchestration page for products list: loads/searches, opens right-drawers, saves product files (path/bytes/stream), and refreshes stock after mutations.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/products/entities/product_file.dart';
import 'package:money_pulse/domain/products/repositories/product_repository.dart';
import 'package:money_pulse/presentation/features/products/product_repo_provider.dart';
import 'package:money_pulse/presentation/features/products/product_file_repo_provider.dart';
import 'package:money_pulse/presentation/widgets/attachments_picker.dart';

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import 'widgets/product_tile.dart';
import 'widgets/product_form_panel.dart';
import 'widgets/product_delete_panel.dart';
import 'widgets/product_view_panel.dart';
import 'widgets/product_stock_adjust_panel.dart';

import 'filters/product_filters.dart';
import 'filters/filters_sheet.dart';

import '../stock/providers/stock_level_repo_provider.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  // ====== FIX: base URI marketplace centralisée ici ======
  static const String _marketplaceBaseUri = 'http://127.0.0.1:8095';

  late final ProductRepository _repo = ref.read(productRepoProvider);
  final _searchCtrl = TextEditingController();
  String _query = '';
  ProductFilters _filters = const ProductFilters();

  void _unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() => _query = _searchCtrl.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _unfocus());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _unfocus();
    if (!mounted) return;
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<List<Product>> _load() async {
    if (_query.trim().isEmpty) {
      final list = await _repo.findAllActive();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }
    final list = await _repo.searchActive(_query, limit: 300);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> _share(Product p) async {
    final text = [
      'Produit: ${p.name ?? p.code ?? '—'}',
      if ((p.description ?? '').isNotEmpty) 'Description: ${p.description}',
      if ((p.code ?? '').isNotEmpty) 'Code: ${p.code}',
      if ((p.barcode ?? '').isNotEmpty) 'EAN: ${p.barcode}',
      'Prix: ${(p.defaultPrice / 100).toStringAsFixed(0)}',
      if (p.purchasePrice > 0)
        'Coût: ${(p.purchasePrice / 100).toStringAsFixed(0)}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Détails copiés')));
  }

  Future<void> _openAdjust(Product p) async {
    _unfocus();
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
      setState(() {});
    }
  }

  Future<String> _persistBytesToDisk(String name, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/product_files');
    if (!await folder.exists()) await folder.create(recursive: true);
    final id = const Uuid().v4();
    final filePath = '${folder.path}/$id-$name';
    final f = File(filePath);
    await f.writeAsBytes(bytes, flush: true);
    return filePath;
  }

  Future<String> _persistStreamToDisk(
    String name,
    Stream<List<int>> stream,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/product_files');
    if (!await folder.exists()) await folder.create(recursive: true);
    final id = const Uuid().v4();
    final filePath = '${folder.path}/$id-$name';
    final sink = File(filePath).openWrite();
    await stream.pipe(sink);
    await sink.flush();
    await sink.close();
    return filePath;
  }

  Future<void> _saveFormFiles(
    String productId,
    List<PickedAttachment> files,
  ) async {
    if (files.isEmpty) return;
    final repo = ref.read(productFileRepoProvider);
    final now = DateTime.now();

    final rows = <ProductFile>[];
    for (int i = 0; i < files.length; i++) {
      final a = files[i];
      String? path = a.path;
      if ((path == null || path.isEmpty) && a.bytes != null) {
        path = await _persistBytesToDisk(a.name, a.bytes!);
      }

      rows.add(
        ProductFile(
          id: const Uuid().v4(),
          productId: productId,
          fileName: a.name,
          mimeType: a.mimeType,
          filePath: path,
          fileSize: a.size,
          isDefault: i == 0 ? 1 : 0,
          createdAt: now,
          updatedAt: now,
          isDirty: 1,
          version: 0,
        ),
      );
    }
    await repo.createMany(rows);
  }

  Future<void> _addOrEdit({Product? existing}) async {
    _unfocus();
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
        purchasePrice: res.purchasePriceCents,
        statuses: res.status,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        syncAt: null,
        version: 0,
        isDirty: 1,
      );
      await _repo.create(p);
      await _saveFormFiles(p.id, res.files);
    } else {
      final updated = existing.copyWith(
        code: res.code,
        name: res.name,
        description: res.description,
        barcode: res.barcode,
        categoryId: res.categoryId,
        defaultPrice: res.priceCents,
        purchasePrice: res.purchasePriceCents,
        statuses: res.status,
        updatedAt: now,
        isDirty: 1,
      );
      await _repo.update(updated);
      await _saveFormFiles(updated.id, res.files);
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _duplicate(Product p) async {
    _unfocus();
    final categories = await ref.read(categoryRepoProvider).findAllActive();
    if (!mounted) return;

    final res = await showRightDrawer<ProductFormResult?>(
      context,
      child: ProductFormPanel(existing: p, categories: categories),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    if (res == null) return;

    final now = DateTime.now();
    final copy = Product(
      id: const Uuid().v4(),
      remoteId: null,
      code: res.code,
      name: res.name,
      description: res.description,
      barcode: res.barcode,
      unitId: p.unitId,
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
    await _repo.create(copy);
    await _saveFormFiles(copy.id, res.files);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _confirmDelete(Product p) async {
    _unfocus();
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
    _unfocus();
    String? catLabel;
    if (p.categoryId != null) {
      final cat = await ref.read(categoryRepoProvider).findById(p.categoryId!);
      catLabel = cat?.code;
    }
    if (!mounted) return;

    final nav = Navigator.of(context);

    await showRightDrawer<void>(
      context,
      child: ProductViewPanel(
        product: p,
        categoryLabel: catLabel,
        marketplaceBaseUri:
            _marketplaceBaseUri, // FIX: on transmet bien l’URL de l’API marketplace
        // publishStatusesCode / unpublishStatusesCode optionnels si tu veux pousser des codes précis
        onEdit: () async {
          if (!mounted) return;
          nav.pop();
          await Future.delayed(const Duration(milliseconds: 60));
          if (!mounted) return;
          await _addOrEdit(existing: p);
        },
        onDelete: () async {
          if (!mounted) return;
          nav.pop();
          await Future.delayed(const Duration(milliseconds: 60));
          if (!mounted) return;
          await _confirmDelete(p);
        },
        onShare: () => _share(p),
        onAdjust: () async {
          if (!mounted) return;
          nav.pop();
          await Future.delayed(const Duration(milliseconds: 60));
          if (!mounted) return;
          await _openAdjust(p);
        },
      ),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
  }

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
      return d.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
          d.isBefore(end.add(const Duration(milliseconds: 1)));
    }

    bool matchPrice(Product p) {
      final min = f.minPriceCents;
      final max = f.maxPriceCents;
      if (min != null && p.defaultPrice < min) return false;
      if (max != null && p.defaultPrice > max) return false;
      return true;
    }

    bool matchStock(Product p) {
      final qty = stockByProduct?[p.id];
      if (f.stock == StockFilter.any) return true;
      if (qty == null) return true;
      if (f.stock == StockFilter.inStock) return qty > 0;
      if (f.stock == StockFilter.outOfStock) return qty <= 0;
      return true;
    }

    return base
        .where((p) => matchDate(p) && matchPrice(p) && matchStock(p))
        .toList();
  }

  Future<void> _openFiltersSheet() async {
    _unfocus();
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
            if (snap.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Produits'),
                  actions: [
                    IconButton(
                      tooltip: 'Rafraîchir',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: 'Ajouter',
                      onPressed: () => _addOrEdit(),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final items = snap.data ?? const <Product>[];
            final stockFuture = _computeStockMap(items);

            return Scaffold(
              appBar: AppBar(
                title: const Text('Produits'),
                actions: [
                  IconButton(
                    tooltip: 'Rafraîchir',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
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
              body: FutureBuilder<Map<String, int>>(
                future: stockFuture,
                builder: (context, stockSnap) {
                  final stockMap = stockSnap.data ?? const <String, int>{};
                  final filtered = _applyLocalFilters(
                    items,
                    stockByProduct: stockMap,
                  );

                  if (items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [SizedBox(height: 60)],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: sidePadding),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filtered.length + 1,
                        separatorBuilder: (_, i) => i == 0
                            ? const SizedBox.shrink()
                            : const Divider(height: 1),
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return _TopBar(
                              total: items.length,
                              searchCtrl: _searchCtrl,
                              filters: _filters,
                              onOpenFilters: _openFiltersSheet,
                              onClearFilters: () => setState(
                                () => _filters = const ProductFilters(),
                              ),
                              onRefresh: _refresh,
                              onUnfocus: _unfocus,
                            );
                          }

                          final p = filtered[i - 1];
                          final title = p.name?.isNotEmpty == true
                              ? p.name!
                              : (p.code ?? 'Produit');
                          final subParts = <String>[];
                          if ((p.description ?? '').isNotEmpty) {
                            subParts.add(p.description!);
                          }
                          if (p.statuses != null && p.statuses!.isNotEmpty) {
                            subParts.add(p.statuses!);
                          }
                          final sub = subParts.join('  •  ');
                          final qty = stockMap[p.id] ?? 0;

                          return ProductTile(
                            title: title,
                            subtitle: sub.isEmpty ? null : sub,
                            priceCents: p.defaultPrice,
                            stockQty: qty,
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
                                case 'duplicate':
                                  await _duplicate(p);
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
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptySection extends StatelessWidget {
  final VoidCallback? onAdd;
  const _EmptySection({required this.onAdd});
  const _EmptySection.placeholder() : onAdd = null;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inventory_2_outlined, size: 72),
        const SizedBox(height: 12),
        const Text(
          'Aucun produit',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text('Ajoutez votre premier produit pour détailler vos achats.'),
        const SizedBox(height: 16),
        if (onAdd != null)
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Nouveau produit'),
          ),
      ],
    );

    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: content),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int total;
  final TextEditingController searchCtrl;
  final ProductFilters filters;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearFilters;
  final Future<void> Function() onRefresh;
  final VoidCallback onUnfocus;

  const _TopBar({
    required this.total,
    required this.searchCtrl,
    required this.filters,
    required this.onOpenFilters,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onUnfocus,
  });

  @override
  Widget build(BuildContext context) {
    final isFiltered = filters != const ProductFilters();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Produits', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text('Total: $total'),
            ),
            ActionChip(
              avatar: const Icon(Icons.tune),
              label: const Text('Filtres'),
              onPressed: () {
                onUnfocus();
                onOpenFilters();
              },
            ),
            if (isFiltered)
              ActionChip(
                avatar: const Icon(Icons.filter_alt_off),
                label: const Text('Effacer les filtres'),
                onPressed: () {
                  onUnfocus();
                  onClearFilters();
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.refresh),
              label: const Text('Rafraîchir'),
              onPressed: () {
                onUnfocus();
                onRefresh();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchCtrl,
                autofocus: false,
                onTapOutside: (_) => onUnfocus(),
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchCtrl.clear();
                            onUnfocus();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onUnfocus(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
