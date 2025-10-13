import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/products/entities/product_file.dart';
import 'package:money_pulse/domain/products/repositories/product_repository.dart';

import 'package:money_pulse/presentation/widgets/attachments_picker.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

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

// ✅ Imports nécessaires pour typer correctement les catégories
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

  // ❗️ Était "dynamic" -> on le **type** correctement
  late final CategoryRepository _categoryRepo;

  late final dynamic _marketRepo;
  late final dynamic _stockRepo;

  @override
  void initState() {
    super.initState();
    _fileRepo = ref.read(productFileRepoProvider);

    // ✅ Provider doit renvoyer un CategoryRepository
    _categoryRepo = ref.read(categoryRepoProvider);

    _stockRepo = ref.read(stockLevelRepoProvider);
    _marketRepo = ref.read(productMarketplaceRepoProvider(_marketplaceBaseUri));
  }

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  // -------------------- Files helpers --------------------
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
      } else if ((path == null || path.isEmpty) && a.readStream != null) {
        path = await _persistStreamToDisk(a.name, a.readStream!);
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

  // -------------------- Product CRUD (+view) --------------------

  /// Méthode publique (utilisée par la page) pour ouvrir l’ajout.
  Future<void> startAdd() => _addOrEdit();

  Future<void> _addOrEdit({Product? existing}) async {
    _unfocus();

    // ✅ On force un type List<Category> ici
    List<Category> categories;
    try {
      final result = await _categoryRepo.findAllActive();
      // Si ton repo renvoie déjà List<Category>, ceci suffit:
      // categories = result;

      // Si ton repo renvoie List<dynamic>, on caste:
      categories = result.cast<Category>();

      // Si (cas extrême) il renvoie List<Map>, utilise:
      // categories = (result as List)
      //     .map((e) => e is Category ? e : Category.fromMap(e as Map<String, Object?>))
      //     .toList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur catégories : $e')));
      return;
    }
    if (!mounted) return;

    final res = await showRightDrawer<ProductFormResult?>(
      context,
      // ✅ On passe bien un List<Category>
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
        quantity: res.quantity,
        hasSold: res.hasSold ? 1 : 0,
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
      await _repo.create(p);
      await _saveFormFiles(p.id, res.files, _fileRepo);
    } else {
      final updated = existing
          .copyWith(
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
            account: existing.account,
            isDirty: 1,
          )
          .copyWith(levelId: res.levelId, version: existing.version);

      final finalUpdated = updated.copyWith(
        quantity: res.quantity,
        hasSold: res.hasSold ? 1 : 0,
        hasPrice: res.hasPrice ? 1 : 0,
        updatedAt: now,
        isDirty: 1,
      );

      await _repo.update(finalUpdated);
      await _saveFormFiles(finalUpdated.id, res.files, _fileRepo);
    }

    ref.invalidate(productsFutureProvider);
    ref.invalidate(stockMapFutureProvider);
    ref.invalidate(imageMapFutureProvider);
  }

  Future<void> _duplicate(Product p) async {
    _unfocus();

    // ✅ Ici aussi on tape fort en List<Category>
    List<Category> categories;
    try {
      final result = await _categoryRepo.findAllActive();
      categories = result.cast<Category>();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur catégories : $e')));
      return;
    }
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
      localId: null,
      code: res.code,
      name: res.name,
      description: res.description,
      barcode: res.barcode,
      unitId: p.unitId,
      categoryId: res.categoryId,
      account: p.account,
      company: res.companyId,
      levelId: res.levelId,
      quantity: res.quantity,
      hasSold: res.hasSold ? 1 : 0,
      hasPrice: res.hasPrice ? 1 : 0,
      defaultPrice: res.priceCents,
      purchasePrice: res.purchasePriceCents,
      statuses: res.status,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncAt: null,
      createdBy: p.createdBy,
      version: 0,
      isDirty: 1,
    );
    await _repo.create(copy);
    await _saveFormFiles(copy.id, res.files, _fileRepo);

    ref.invalidate(productsFutureProvider);
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
      final remoteId = (p.remoteId ?? '').trim();
      if (remoteId.isNotEmpty) {
        try {
          await _marketRepo.deleteRemote(p);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Avertissement : échec de la suppression distante ($e)',
                ),
              ),
            );
          }
        }
      }
      await _repo.softDelete(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Produit supprimé.')));

      ref.invalidate(productsFutureProvider);
    }
  }

  Future<void> _view(Product p) async {
    _unfocus();
    String? catLabel;
    if (p.categoryId != null) {
      final cat = await _categoryRepo.findById(p.categoryId!);
      catLabel = cat?.code;
    }
    if (!mounted) return;

    final nav = Navigator.of(context);
    final shouldRefresh = await showRightDrawer<bool>(
      context,
      child: ProductViewPanel(
        product: p,
        categoryLabel: catLabel,
        marketplaceBaseUri: _marketplaceBaseUri,
        onEdit: () async {
          if (!mounted) return;
          nav.pop(false);
          await Future.delayed(const Duration(milliseconds: 60));
          if (!mounted) return;
          await _addOrEdit(existing: p);
        },
        onDelete: () async {
          if (!mounted) return;
          nav.pop(false);
          await Future.delayed(const Duration(milliseconds: 60));
          if (!mounted) return;
          await _confirmDelete(p);
        },
        onShare: () => _share(p),
        onAdjust: () async {
          if (!mounted) return;
          nav.pop(false);
          await Future.delayed(const Duration(milliseconds: 60));
          if (!mounted) return;
          await _openAdjust(p);
        },
      ),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );

    if (shouldRefresh == true && mounted) {
      ref.invalidate(productsFutureProvider);
      ref.invalidate(stockMapFutureProvider);
    }
  }

  // -------------------- Quick actions --------------------
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
      ref.invalidate(productsFutureProvider);
      ref.invalidate(stockMapFutureProvider);
    }
  }

  Future<void> _markSoldOut(Product p) async {
    final now = DateTime.now();
    final statuses = (p.statuses ?? '').trim();
    final hasTag = statuses.split(RegExp(r'\s*,\s*|\s+')).contains('SOLD_OUT');
    final merged = hasTag
        ? statuses
        : (statuses.isEmpty ? 'SOLD_OUT' : '$statuses,SOLD_OUT');

    await _repo.update(
      p.copyWith(quantity: 0, statuses: merged, updatedAt: now, isDirty: 1),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produit marqué comme épuisé')),
    );
    ref.invalidate(productsFutureProvider);
    ref.invalidate(stockMapFutureProvider);
  }

  // -------------------- Build --------------------
  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsFutureProvider);
    final filters = ref.watch(productFiltersProvider);
    final queryCtrl = widget.queryController;

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erreur de chargement: $e'),
        ),
      ),
      data: (items) {
        final stockMapAsync = ref.watch(stockMapFutureProvider(items));
        final imageMapAsync = ref.watch(imageMapFutureProvider(items));

        return RefreshIndicator(
          onRefresh: () async =>
              ref.read(productsFutureProvider.notifier).refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length + 1,
            separatorBuilder: (_, i) =>
                i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
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
                      useSafeArea: true,
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

              stockMapAsync.maybeWhen(orElse: () {}, data: (_) {});

              final imagePath = imageMapAsync.maybeWhen(
                data: (m) => m[p.id],
                orElse: () => null,
              );

              final subParts = <String>[];
              if ((p.description ?? '').isNotEmpty)
                subParts.add(p.description!);
              if ((p.statuses ?? '').isNotEmpty) subParts.add(p.statuses!);
              final sub = subParts.join('  •  ');
              final title = p.name?.isNotEmpty == true
                  ? p.name!
                  : (p.code ?? 'Produit');

              return ProductTile(
                title: title,
                subtitle: sub.isEmpty ? null : sub,
                priceCents: p.defaultPrice,
                statuses: p.statuses,
                remoteId: p.remoteId,
                imagePath: imagePath,
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
                    case 'soldout':
                      await _markSoldOut(p);
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
