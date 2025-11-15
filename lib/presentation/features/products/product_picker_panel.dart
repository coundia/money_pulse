// Right-drawer to search/pick products with quantity/price editing, top actions row, Enter-to-validate, and quick access to list/new-product.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:jaayko/presentation/shared/formatters.dart';
import 'package:jaayko/presentation/widgets/right_drawer.dart';

import 'package:jaayko/domain/products/entities/product.dart';
import '../../app/providers.dart';
import 'product_repo_provider.dart';

import 'package:jaayko/presentation/features/products/widgets/product_form_panel.dart';
import 'package:jaayko/presentation/features/products/product_list_page.dart';

class ProductPickerPanel extends ConsumerStatefulWidget {
  final List<Map<String, Object?>> initialLines;
  const ProductPickerPanel({super.key, this.initialLines = const []});

  @override
  ConsumerState<ProductPickerPanel> createState() => _ProductPickerPanelState();
}

class _ProductPickerPanelState extends ConsumerState<ProductPickerPanel> {
  final searchCtrl = TextEditingController();
  final Map<String, _Line> _selected = {};
  final Map<String, TextEditingController> _qtyCtrls = {};
  List<Product> _all = const [];
  bool _loading = false;
  bool _onlySelected = false;
  _SortBy _sortBy = _SortBy.updatedDesc;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(productRepoProvider);
      final items = await repo.findAllActive();
      if (!mounted) return;
      setState(() {
        _all = items;
        for (final m in widget.initialLines) {
          final id = m['productId'] as String?;
          if (id == null) continue;
          final p = items.any((e) => e.id == id)
              ? items.firstWhere((e) => e.id == id)
              : Product(
                  id: id,
                  remoteId: null,
                  code: null,
                  name: (m['label'] as String?) ?? 'Produit',
                  description: null,
                  barcode: null,
                  unitId: null,
                  categoryId: null,
                  defaultPrice:
                      (m['unitPriceCents'] as int?) ??
                      (m['unitPrice'] as int?) ??
                      0,
                  purchasePrice: 0,
                  statuses: 'ACTIVE',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  deletedAt: null,
                  syncAt: null,
                  version: 0,
                  isDirty: 1,
                );
          final q = (m['quantity'] as int?) ?? 1;
          final up =
              (m['unitPriceCents'] as int?) ??
              (m['unitPrice'] as int?) ??
              p.defaultPrice;
          _selected[id] = _Line(product: p, quantity: q, unitPriceCents: up);
          _ensureQtyCtrl(id, q);
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ensureQtyCtrl(String id, int initial) {
    return _qtyCtrls.putIfAbsent(
      id,
      () => TextEditingController(text: initial.toString()),
    );
  }

  void _disposeQtyCtrl(String id) {
    final c = _qtyCtrls.remove(id);
    c?.dispose();
  }

  List<Product> get _source {
    final q = searchCtrl.text.trim().toLowerCase();
    Iterable<Product> src = _all;
    if (_onlySelected) {
      final ids = _selected.keys.toSet();
      src = src.where((p) => ids.contains(p.id));
    }
    if (q.isNotEmpty) {
      src = src.where((p) {
        final s1 = (p.name ?? '').toLowerCase();
        final s2 = (p.code ?? '').toLowerCase();
        final s3 = (p.barcode ?? '').toLowerCase();
        return s1.contains(q) || s2.contains(q) || s3.contains(q);
      });
    }
    final list = src.toList();
    switch (_sortBy) {
      case _SortBy.updatedDesc:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case _SortBy.name:
        list.sort(
          (a, b) => (a.name ?? '').toLowerCase().compareTo(
            (b.name ?? '').toLowerCase(),
          ),
        );
        break;
      case _SortBy.price:
        list.sort((a, b) => (a.defaultPrice).compareTo(b.defaultPrice));
        break;
    }
    return list;
  }

  int get _totalCents =>
      _selected.values.fold(0, (s, l) => s + (l.unitPriceCents * l.quantity));

  void _toggle(Product p) {
    setState(() {
      if (_selected.containsKey(p.id)) {
        _selected.remove(p.id);
        _disposeQtyCtrl(p.id);
      } else {
        _selected[p.id] = _Line(
          product: p,
          quantity: 1,
          unitPriceCents: p.defaultPrice,
        );
        _ensureQtyCtrl(p.id, 1);
      }
    });
  }

  void _setQty(Product p, int qty) {
    if (qty < 0) qty = 0;
    setState(() {
      final cur = _selected[p.id] ?? _Line(product: p);
      if (qty == 0) {
        _selected.remove(p.id);
        _disposeQtyCtrl(p.id);
      } else {
        _selected[p.id] = cur.copyWith(quantity: qty);
        _ensureQtyCtrl(p.id, qty).text = qty.toString();
      }
    });
  }

  void _incQty(Product p) {
    final cur = _selected[p.id];
    if (cur == null) {
      setState(() {
        _selected[p.id] = _Line(
          product: p,
          quantity: 1,
          unitPriceCents: p.defaultPrice,
        );
        _ensureQtyCtrl(p.id, 1);
      });
    } else {
      _setQty(p, cur.quantity + 1);
    }
  }

  void _decQty(Product p) {
    final cur = _selected[p.id];
    if (cur == null) return;
    _setQty(p, cur.quantity - 1);
  }

  void _setPrice(Product p, int cents) {
    if (cents < 0) cents = 0;
    setState(() {
      final cur = _selected[p.id] ?? _Line(product: p, quantity: 1);
      final fixedQty = cur.quantity == 0 ? 1 : cur.quantity;
      _selected[p.id] = cur.copyWith(unitPriceCents: cents, quantity: fixedQty);
      _ensureQtyCtrl(p.id, fixedQty);
    });
  }

  Future<void> _editPriceDialog(Product p) async {
    final init = _selected[p.id]?.unitPriceCents ?? p.defaultPrice;
    final ctrl = TextEditingController(text: (init / 100).toStringAsFixed(2));
    final res = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Prix unitaire'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Prix unitaire',
            hintText: '0,00',
          ),
          autofocus: true,
          onSubmitted: (_) => Navigator.of(d).pop(_toCents(ctrl.text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(_toCents(ctrl.text)),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (res != null) _setPrice(p, res);
  }

  int _toCents(String v) {
    final s = v.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    final d = double.tryParse(s) ?? 0;
    return (d * 100).round();
  }

  void _clearAll() {
    setState(() {
      _selected.clear();
      for (final id in _qtyCtrls.keys.toList()) {
        _disposeQtyCtrl(id);
      }
    });
  }

  void _submit() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un produit')),
      );
      return;
    }
    final list = _selected.values
        .where((l) => l.quantity > 0)
        .map(
          (l) => {
            'productId': l.product.id,
            'label': l.product.name ?? 'Produit',
            'unitPrice': l.unitPriceCents,
            'unitPriceCents': l.unitPriceCents,
            'quantity': l.quantity,
          },
        )
        .toList();
    Navigator.of(context).pop(list);
  }

  Future<void> _openProductList() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProductListPage()));
    if (!mounted) return;
    final repo = ref.read(productRepoProvider);
    final refreshed = await repo.findAllActive();
    setState(() => _all = refreshed);
  }

  Future<void> _createProduct() async {
    final categories = await ref.read(categoryRepoProvider).findAllActive();
    if (!mounted) return;
    final res = await showRightDrawer<ProductFormResult?>(
      context,
      child: ProductFormPanel(existing: null, categories: categories),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    if (res == null) return;

    final now = DateTime.now();
    final repo = ref.read(productRepoProvider);
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
    final items = await repo.findAllActive();
    if (!mounted) return;
    setState(() {
      _all = items;
      _selected[p.id] = _Line(
        product: p,
        quantity: 1,
        unitPriceCents: p.defaultPrice,
      );
      _ensureQtyCtrl(p.id, 1);
      _sortBy = _SortBy.updatedDesc;
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Produit ajouté et sélectionné')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loading;
    final width = MediaQuery.of(context).size.width;
    final trailingMax = width < 360
        ? 120.0
        : width < 420
        ? 148.0
        : 180.0;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const _SubmitIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _SubmitIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SubmitIntent: CallbackAction<_SubmitIntent>(
            onInvoke: (_) {
              _submit();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Sélectionner des produits'),
            leading: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              IconButton(
                tooltip: 'Liste des produits',
                onPressed: _openProductList,
                icon: const Icon(Icons.view_list),
              ),
              IconButton(
                tooltip: 'Nouveau produit',
                onPressed: _createProduct,
                icon: const Icon(Icons.add),
              ),
              TextButton(onPressed: _clearAll, child: const Text('Vider')),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text('Valider'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Rechercher',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<_SortBy>(
                      tooltip: 'Trier',
                      icon: const Icon(Icons.filter_list),
                      onSelected: (v) => setState(() => _sortBy = v),
                      itemBuilder: (c) => const [
                        PopupMenuItem(
                          value: _SortBy.updatedDesc,
                          child: Text('Dernière mise à jour'),
                        ),
                        PopupMenuItem(value: _SortBy.name, child: Text('Nom')),
                        PopupMenuItem(
                          value: _SortBy.price,
                          child: Text('Prix défaut'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Tous'),
                      selected: !_onlySelected,
                      onSelected: (v) => setState(() => _onlySelected = !v),
                    ),
                    ChoiceChip(
                      label: Text('Sélection: ${_selected.length}'),
                      selected: _onlySelected,
                      onSelected: (v) => setState(() => _onlySelected = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),
              if (loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: _source.isEmpty
                      ? _EmptyState(
                          onOpenList: _openProductList,
                          onCreate: _createProduct,
                        )
                      : ListView.separated(
                          itemCount: _source.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = _source[i];
                            final sel = _selected[p.id];
                            final qty = sel?.quantity ?? 1;
                            final unit = sel?.unitPriceCents ?? p.defaultPrice;
                            final lineTotal = unit * qty;
                            final selected = _selected.containsKey(p.id);
                            final qtyCtrl = _ensureQtyCtrl(p.id, qty);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              leading: Checkbox(
                                visualDensity: VisualDensity.compact,
                                value: selected,
                                onChanged: (_) => _toggle(p),
                              ),
                              title: Text(
                                p.name ?? 'Produit',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    lineTotal == 0
                                        ? '—'
                                        : Formatters.amountFromCents(lineTotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: trailingMax,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Réduire',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: selected
                                          ? () => _decQty(p)
                                          : null,
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 48,
                                      child: TextField(
                                        controller: qtyCtrl,
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (v) => _setQty(
                                          p,
                                          int.tryParse(v.trim()) ?? 0,
                                        ),
                                        onSubmitted: (_) => _submit(),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Augmenter',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _incQty(p),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Prix',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _editPriceDialog(p),
                                      icon: const Icon(Icons.sell),
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () => _toggle(p),
                              onLongPress: () => _editPriceDialog(p),
                              selected: selected,
                              dense: true,
                            );
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}

enum _SortBy { updatedDesc, name, price }

class _Line {
  final Product product;
  final int quantity;
  final int unitPriceCents;
  const _Line({
    required this.product,
    this.quantity = 1,
    this.unitPriceCents = 0,
  });
  _Line copyWith({int? quantity, int? unitPriceCents}) => _Line(
    product: product,
    quantity: quantity ?? this.quantity,
    unitPriceCents: unitPriceCents ?? this.unitPriceCents,
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onOpenList;
  final VoidCallback onCreate;
  const _EmptyState({required this.onOpenList, required this.onCreate});

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
            const Text('Créez un produit ou ouvrez la liste.'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenList,
                  icon: const Icon(Icons.view_list),
                  label: const Text('Liste des produits'),
                ),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouveau produit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
