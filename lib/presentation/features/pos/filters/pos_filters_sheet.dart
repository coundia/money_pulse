// Bottom sheet to edit POS filters with category and price range.
import 'package:flutter/material.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'pos_filters.dart';

class PosFiltersSheet extends StatefulWidget {
  final PosFilters initial;
  final List<Category> categories;
  const PosFiltersSheet({
    super.key,
    required this.initial,
    required this.categories,
  });

  @override
  State<PosFiltersSheet> createState() => _PosFiltersSheetState();
}

class _PosFiltersSheetState extends State<PosFiltersSheet> {
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
                  ...widget.categories.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.code)),
                  ),
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
