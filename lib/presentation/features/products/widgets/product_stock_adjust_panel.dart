// widgets/product_stock_adjust_panel.dart
// Right drawer to adjust product stock and also update Product.quantity accordingly.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/features/stock/providers/stock_level_repo_provider.dart';
// ⬇️ NEW: update product repo to keep Product.quantity in sync
import 'package:money_pulse/presentation/features/products/product_repo_provider.dart';

class ProductStockAdjustPanel extends ConsumerStatefulWidget {
  final Product product;
  const ProductStockAdjustPanel({super.key, required this.product});

  @override
  ConsumerState<ProductStockAdjustPanel> createState() =>
      _ProductStockAdjustPanelState();
}

enum _AdjustMode { byDelta, toTarget }

class _ProductStockAdjustPanelState
    extends ConsumerState<ProductStockAdjustPanel> {
  final _formKey = GlobalKey<FormState>();

  _AdjustMode _mode = _AdjustMode.byDelta;
  final _qtyCtrl = TextEditingController(text: '1');
  final _targetCtrl = TextEditingController(text: '0');
  final _reasonCtrl = TextEditingController();

  String? _companyId;
  List<Map<String, Object?>> _companies = const [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(stockLevelRepoProvider);
      final cos = await repo.listCompanies(query: '');
      if (!mounted) return;
      setState(() {
        _companies = cos;
        _companyId = (cos.isNotEmpty
            ? (cos.first['id']?.toString() ?? '')
            : null);
      });
    });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _targetCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_companyId ?? '').isEmpty) {
      _safeSnack('Sélectionnez une société');
      return;
    }

    setState(() => _loading = true);
    final stockRepo = ref.read(stockLevelRepoProvider);
    // NEW: product repo to mirror quantity locally
    final productRepo = ref.read(productRepoProvider);

    try {
      final now = DateTime.now();
      int newQty = widget.product.quantity;

      if (_mode == _AdjustMode.byDelta) {
        final delta = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
        if (delta == 0) {
          _safeSnack('La variation ne peut pas être 0');
          return;
        }
        await stockRepo.adjustOnHandBy(
          productVariantId: widget.product.id,
          companyId: _companyId!,
          delta: delta,
          reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text,
        );
        // NEW: mirror locally on the Product row
        newQty = (widget.product.quantity + delta);
      } else {
        final target = int.tryParse(_targetCtrl.text.trim()) ?? 0;
        await stockRepo.adjustOnHandTo(
          productVariantId: widget.product.id,
          companyId: _companyId!,
          target: target,
          reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text,
        );
        // NEW: mirror locally on the Product row
        newQty = target;
      }

      // Clamp to ≥ 0, mark dirty and update timestamp
      if (newQty < 0) newQty = 0;

      await productRepo.update(
        widget.product.copyWith(quantity: newQty, updatedAt: now, isDirty: 1),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _safeSnack(String msg) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final title = (p.name?.isNotEmpty == true) ? p.name! : 'Produit';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuster le stock'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(false),
        ),
        actions: [
          IconButton(
            tooltip: 'Enregistrer',
            onPressed: _loading ? null : _submit,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      child: Text(
                        (title.isNotEmpty ? title.characters.first : '?')
                            .toUpperCase(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Chip(
                                label: Text(
                                  'PU par défaut: ${Formatters.amountFromCents(p.defaultPrice)}',
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              Chip(
                                label: Text('Stock actuel: ${p.quantity}'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _companyId,
                  items: _companies
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e['id']?.toString(),
                          child: Text((e['label'] as String?) ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _companyId = v),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Société',
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<_AdjustMode>(
                  segments: const [
                    ButtonSegment(
                      value: _AdjustMode.byDelta,
                      label: Text('Varier ±N'),
                      icon: Icon(Icons.unfold_more_double),
                    ),
                    ButtonSegment(
                      value: _AdjustMode.toTarget,
                      label: Text('Fixer à N'),
                      icon: Icon(Icons.table_rows_rounded),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 12),
                if (_mode == _AdjustMode.byDelta)
                  TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d+')),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Variation (peut être négative)',
                      hintText: 'Ex: 5 ou -3',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Obligatoire';
                      final n = int.tryParse(v.trim());
                      if (n == null || n == 0) return 'Entrez un entier ≠ 0';
                      return null;
                    },
                  ),
                if (_mode == _AdjustMode.toTarget)
                  TextFormField(
                    controller: _targetCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Quantité cible (≥ 0)',
                      hintText: 'Ex: 12',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Obligatoire';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 0) return 'Entrez un entier ≥ 0';
                      return null;
                    },
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Motif (optionnel)',
                    hintText: 'Ex: “Inventaire”, “Correction”, …',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: const Icon(Icons.check),
                  label: Text(_loading ? 'Enregistrement…' : 'Valider'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
