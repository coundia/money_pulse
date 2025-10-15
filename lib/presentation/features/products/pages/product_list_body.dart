// Product list orchestration (page): applies all ProductFormResult fields on create & update,
// including quantity, hasSold, hasPrice, company & level; adds debug logs for before/after.

import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/products/entities/product_file.dart';
import 'package:money_pulse/domain/products/repositories/product_repository.dart';

import 'package:money_pulse/presentation/widgets/attachments_picker.dart';

import '../../../../infrastructure/products/product_marketplace_repo_provider.dart';
import '../../../../shared/constants/env.dart';
import '../../../app/providers.dart';
import '../product_file_repo_provider.dart';
import '../product_repo_provider.dart';
import '../widgets/product_form_panel.dart';
import '../widgets/product_delete_panel.dart';
import '../widgets/product_tile.dart';
import '../widgets/product_view_panel.dart';
import '../widgets/product_stock_adjust_panel.dart';
import '../filters/filters_sheet.dart';
import '../filters/product_filters.dart';
import '../../stock/providers/stock_level_repo_provider.dart';
import '../widgets/top_bar.dart';
import '../application/product_list_providers.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/categories/repositories/category_repository.dart';

class ProductListBody extends ConsumerStatefulWidget {
  final TextEditingController queryController;
  const ProductListBody({super.key, required this.queryController});

  @override
  ConsumerState<ProductListBody> createState() => ProductListBodyState();
}

class ProductListBodyState extends ConsumerState<ProductListBody> {
  static const String _marketplaceBaseUri = Env.BASE_URI;

  late final ProductRepository _repo = ref.read(productRepoProvider);
  late final dynamic _fileRepo;
  late final CategoryRepository _categoryRepo;
  late final dynamic _marketRepo;
  late final dynamic _stockRepo;

  @override
  void initState() {
    super.initState();
    _fileRepo = ref.read(productFileRepoProvider);
    _categoryRepo = ref.read(categoryRepoProvider);
    _stockRepo = ref.read(stockLevelRepoProvider);
    _marketRepo = ref.read(productMarketplaceRepoProvider(_marketplaceBaseUri));
  }

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

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

  Future<void> _saveFormFiles(
    String productId,
    List<PickedAttachment> files,
    dynamic repo,
  ) async {
    if (files.isEmpty) return;
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

  Future<void> startAdd() => _addOrEdit();

  Future<void> _addOrEdit({Product? existing}) async {
    _unfocus();
    List<Category> categories = [];
    try {
      categories = (await _categoryRepo.findAllActive()).cast<Category>();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur catégories : $e')));
      }
      return;
    }

    final res = await Navigator.push<ProductFormResult?>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductFormPanel(existing: existing, categories: categories),
        fullscreenDialog: true,
      ),
    );
    if (res == null) return;

    final now = DateTime.now();

    if (existing == null) {
      // CREATE
      final p = Product(
        id: const Uuid().v4(),
        remoteId: null,
        localId: null,
        code: res.code,
        name: res.name,
        description: res.description,
        barcode: res.barcode,
        unitId: null,
        categoryId: res.categoryId,
        account: null,
        company: res.companyId,
        levelId: res.levelId,
        quantity: res.quantity, // ✅ apply quantity
        hasSold: res.hasSold ? 1 : 0, // ✅ apply flags
        hasPrice: res.hasPrice ? 1 : 0,
        defaultPrice: res.priceCents,
        purchasePrice: res.purchasePriceCents,
        statuses: res.status,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        syncAt: null,
        createdBy: null,
        version: 0,
        isDirty: 1,
      );

      dev.log(
        'CREATE apply qty=${p.quantity}, hasSold=${p.hasSold}, hasPrice=${p.hasPrice}',
        name: 'ProductListBody',
      );

      await _repo.create(p);
      await _saveFormFiles(p.id, res.files, _fileRepo);
    } else {
      // UPDATE (fix: also update quantity, flags, level & company)
      dev.log(
        'UPDATE before qty=${existing.quantity} → form qty=${res.quantity}',
        name: 'ProductListBody',
      );

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
        company: res.companyId,
        levelId: res.levelId,
        quantity: res.quantity, // ✅ FIX: propagate quantity
        hasSold: res.hasSold ? 1 : 0, // ✅ FIX: propagate flags
        hasPrice: res.hasPrice ? 1 : 0,
        isDirty: 1,
      );

      dev.log(
        'UPDATE apply qty=${updated.quantity}, hasSold=${updated.hasSold}, hasPrice=${updated.hasPrice}',
        name: 'ProductListBody',
      );

      await _repo.update(updated);
      await _saveFormFiles(updated.id, res.files, _fileRepo);
    }

    ref.invalidate(productsFutureProvider);
  }

  Future<void> _confirmDelete(Product p) async {
    _unfocus();
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductDeletePanel(product: p)),
    );
    if (ok == true) {
      await _repo.softDelete(p.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Produit supprimé.')));
      }
      ref.invalidate(productsFutureProvider);
    }
  }

  Future<void> _view(Product p) async {
    _unfocus();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductViewPanel(
          product: p,
          marketplaceBaseUri: _marketplaceBaseUri,
          onEdit: () async => _addOrEdit(existing: p),
          onDelete: () async => _confirmDelete(p),
          onShare: () => _share(p),
          onAdjust: () async => _openAdjust(p),
        ),
      ),
    );
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
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Détails copiés')));
    }
  }

  Future<void> _openAdjust(Product p) async {
    _unfocus();
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductStockAdjustPanel(product: p)),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stock ajusté.')));
      ref.invalidate(productsFutureProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsFutureProvider);
    final filters = ref.watch(productFiltersProvider);
    final queryCtrl = widget.queryController;

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (items) {
        return RefreshIndicator(
          onRefresh: () async =>
              ref.read(productsFutureProvider.notifier).refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              if (i == 0) {
                return TopBar(
                  total: items.length,
                  searchCtrl: queryCtrl,
                  filters: filters,
                  onOpenFilters: () async {
                    _unfocus();
                    final res = await showModalBottomSheet<ProductFilters>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => FiltersSheet(
                        initial: ref.read(productFiltersProvider),
                      ),
                    );
                    if (res != null) {
                      ref.read(productFiltersProvider.notifier).state = res;
                      ref.invalidate(productsFutureProvider);
                    }
                  },
                  onClearFilters: () {
                    _unfocus();
                    ref.read(productFiltersProvider.notifier).state =
                        const ProductFilters();
                    ref.invalidate(productsFutureProvider);
                  },
                  onRefresh: () =>
                      ref.read(productsFutureProvider.notifier).refresh(),
                  onUnfocus: _unfocus,
                );
              }

              final p = items[i - 1];
              final sub = [
                if ((p.description ?? '').isNotEmpty) p.description!,
                if ((p.statuses ?? '').isNotEmpty) p.statuses!,
              ].join('  •  ');

              return ProductTile(
                title: p.name ?? p.code ?? 'Produit',
                subtitle: sub.isEmpty ? null : sub,
                priceCents: p.defaultPrice,
                statuses: p.statuses,
                imageUrl: null,
                onTap: () => _view(p),
                onMenuAction: (action) async {
                  switch (action) {
                    case 'view':
                      await _view(p);
                      break;
                    case 'edit':
                      await _addOrEdit(existing: p);
                      break;
                    case 'duplicate':
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
    );
  }
}
