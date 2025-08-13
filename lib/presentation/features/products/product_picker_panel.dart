// ProductPickerPanel: right-drawer to search, pick products, adjust quantity and unit price with enhanced UX and Enter-to-validate.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/domain/products/entities/product.dart';

import 'product_repo_provider.dart';

class ProductPickerPanel extends ConsumerStatefulWidget {
  final List<Map<String, Object?>> initialLines;
  const ProductPickerPanel({super.key, this.initialLines = const []});

  @override
  ConsumerState<ProductPickerPanel> createState() => _ProductPickerPanelState();
}

class _ProductPickerPanelState extends ConsumerState<ProductPickerPanel> {
  final searchCtrl = TextEditingController();
  final Map<String, _Line> _selected = {};
  List<Product> _all = const [];
  bool _loading = false;
  bool _onlySelected = false;
  _SortBy _sortBy = _SortBy.name;

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
          final p = items.where((e) => e.id == id).isNotEmpty
              ? items.firstWhere((e) => e.id == id)
              : Product(
                  id: id,
                  name: (m['label'] as String?) ?? 'Produit',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
          _selected[id] = _Line(
            product: p,
            quantity: (m['quantity'] as int?) ?? 1,
            unitPriceCents:
                (m['unitPriceCents'] as int?) ??
                (m['unitPrice'] as int?) ??
                p.defaultPrice,
          );
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
    super.dispose();
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
      case _SortBy.name:
        list.sort(
          (a, b) => (a.name ?? '').toLowerCase().compareTo(
            (b.name ?? '').toLowerCase(),
          ),
        );
        break;
      case _SortBy.code:
        list.sort(
          (a, b) => (a.code ?? '').toLowerCase().compareTo(
            (b.code ?? '').toLowerCase(),
          ),
        );
        break;
      case _SortBy.price:
        list.sort((a, b) => (a.defaultPrice).compareTo(b.defaultPrice));
        break;
    }
    return list;
  }

  int get _totalCents => _selected.values.fold(
    0,
    (sum, l) => sum + (l.unitPriceCents * l.quantity),
  );

  void _toggle(Product p) {
    setState(() {
      if (_selected.containsKey(p.id)) {
        _selected.remove(p.id);
      } else {
        _selected[p.id] = _Line(
          product: p,
          quantity: 1,
          unitPriceCents: p.defaultPrice,
        );
      }
    });
  }

  void _setQty(Product p, int qty) {
    if (qty < 0) qty = 0;
    setState(() {
      final cur = _selected[p.id] ?? _Line(product: p);
      if (qty == 0) {
        _selected.remove(p.id);
      } else {
        _selected[p.id] = cur.copyWith(quantity: qty);
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
      _selected[p.id] = cur.copyWith(
        unitPriceCents: cents,
        quantity: cur.quantity == 0 ? 1 : cur.quantity,
      );
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

  Future<void> _editQtyDialog(Product p) async {
    final cur = _selected[p.id];
    final init = cur?.quantity ?? 1;
    final ctrl = TextEditingController(text: init.toString());
    final res = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Quantité'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Quantité',
            hintText: '1',
          ),
          autofocus: true,
          onSubmitted: (_) =>
              Navigator.of(d).pop(int.tryParse(ctrl.text.trim()) ?? init),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(d).pop(int.tryParse(ctrl.text.trim()) ?? init),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (res != null) _setQty(p, res);
  }

  void _bulkApplyDefaultPrices() {
    setState(() {
      for (final id in _selected.keys.toList()) {
        final line = _selected[id]!;
        _selected[id] = line.copyWith(
          unitPriceCents: line.product.defaultPrice,
        );
      }
    });
  }

  int _toCents(String v) {
    final s = v.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    final d = double.tryParse(s) ?? 0;
    return (d * 100).round();
  }

  void _clearAll() {
    setState(() => _selected.clear());
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

  @override
  Widget build(BuildContext context) {
    final loading = _loading;
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
                        decoration: InputDecoration(
                          labelText: 'Rechercher un produit',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Effacer',
                                  onPressed: () {
                                    searchCtrl.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<_SortBy>(
                      tooltip: 'Trier',
                      icon: const Icon(Icons.sort),
                      onSelected: (v) => setState(() => _sortBy = v),
                      itemBuilder: (c) => const [
                        PopupMenuItem(
                          value: _SortBy.name,
                          child: Text('Tri: nom'),
                        ),
                        PopupMenuItem(
                          value: _SortBy.code,
                          child: Text('Tri: code'),
                        ),
                        PopupMenuItem(
                          value: _SortBy.price,
                          child: Text('Tri: prix défaut'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('Sélection: ${_selected.length}'),
                      selected: _onlySelected,
                      onSelected: (v) => setState(() => _onlySelected = v),
                    ),
                    const SizedBox(width: 8),
                    InputChip(
                      avatar: const Icon(Icons.summarize, size: 18),
                      label: Text(
                        'Total: ${Formatters.amountFromCents(_totalCents)}',
                      ),
                      onPressed: _selected.isEmpty ? null : _submit,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : _bulkApplyDefaultPrices,
                      icon: const Icon(Icons.price_change),
                      label: const Text('Prix par défaut'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: _source.isEmpty
                      ? const Center(child: Text('Aucun produit'))
                      : ListView.separated(
                          itemCount: _source.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final p = _source[i];
                            final sel = _selected[p.id];
                            final qty = sel?.quantity ?? 0;
                            final unit = sel?.unitPriceCents ?? p.defaultPrice;
                            final lineTotal = unit * qty;
                            final selected = _selected.containsKey(p.id);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              leading: Checkbox(
                                value: selected,
                                onChanged: (_) => _toggle(p),
                              ),
                              title: Text(
                                p.name ?? 'Produit',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (p.code?.isNotEmpty ?? false)
                                        ? 'Code: ${p.code}'
                                        : (p.barcode?.isNotEmpty ?? false)
                                        ? 'Code-barres: ${p.barcode}'
                                        : 'Sans code',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () => _editPriceDialog(p),
                                        child: Chip(
                                          label: Text(
                                            unit == 0
                                                ? 'Prix: —'
                                                : 'Prix: ${Formatters.amountFromCents(unit)}',
                                          ),
                                          avatar: const Icon(
                                            Icons.sell,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _editQtyDialog(p),
                                        child: Chip(
                                          label: Text('Qté: $qty'),
                                          avatar: const Icon(
                                            Icons.numbers,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: SizedBox(
                                width: 148,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      tooltip: 'Réduire',
                                      onPressed: selected
                                          ? () => _decQty(p)
                                          : null,
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    Text(
                                      '$qty',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Augmenter',
                                      onPressed: () => _incQty(p),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () => _toggle(p),
                              selected: selected,
                              selectedTileColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              dense: true,
                            );
                          },
                        ),
                ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sélection: ${_selected.length} article(s)'),
                            Text(
                              'Total: ${Formatters.amountFromCents(_totalCents)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check),
                        label: const Text('Valider'),
                      ),
                    ],
                  ),
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

enum _SortBy { name, code, price }

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
