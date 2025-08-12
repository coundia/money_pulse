import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/products/repositories/product_repository.dart';
import 'package:money_pulse/presentation/features/products/product_repo_provider.dart';

import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/presentation/app/providers.dart'; // for categoryRepoProvider

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  late final ProductRepository _repo = ref.read(productRepoProvider);
  final _searchCtrl = TextEditingController();
  String _query = '';

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

  String _money(int cents) {
    final v = cents / 100.0;
    return NumberFormat.currency(symbol: '', decimalDigits: 0).format(v);
  }

  Future<void> _addOrEdit({Product? existing}) async {
    final categories = await ref.read(categoryRepoProvider).findAllActive();
    if (!mounted) return;

    final res = await showDialog<_ProductFormResult>(
      context: context,
      builder: (_) =>
          _ProductDialog(existing: existing, categories: categories),
    );
    if (res == null) return;

    final now = DateTime.now();
    if (existing == null) {
      final p = Product(
        id: const Uuid().v4(),
        remoteId: null,
        code: res.code?.isEmpty == true ? null : res.code!.trim(),
        name: res.name?.isEmpty == true ? null : res.name!.trim(),
        description: res.description?.isEmpty == true
            ? null
            : res.description!.trim(),
        barcode: res.barcode?.isEmpty == true ? null : res.barcode!.trim(),
        unitId: null, // extend later if you add units
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
        code: res.code?.isEmpty == true ? null : res.code!.trim(),
        name: res.name?.isEmpty == true ? null : res.name!.trim(),
        description: res.description?.isEmpty == true
            ? null
            : res.description!.trim(),
        barcode: res.barcode?.isEmpty == true ? null : res.barcode!.trim(),
        categoryId: res.categoryId,
        defaultPrice: res.priceCents,
      );
      await _repo.update(updated);
    }
    if (mounted) setState(() {});
  }

  // 1) Safer confirm+delete that uses the dialog's own context
  Future<void> _delete(Product p) async {
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le produit ?'),
        content: Text(
          '« ${p.name ?? p.code ?? 'Produit'} » sera déplacé dans la corbeille.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _repo.softDelete(p.id);
      if (!mounted) return;
      setState(() {}); // reload list
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _load(),
      builder: (context, snap) {
        final items = snap.data ?? const <Product>[];

        final body = switch (snap.connectionState) {
          ConnectionState.waiting => const Center(
            child: CircularProgressIndicator(),
          ),
          _ =>
            items.isEmpty
                ? _empty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, i) => i == 0
                        ? const SizedBox.shrink()
                        : const Divider(height: 1),
                    itemBuilder: (_, i) {
                      if (i == 0) return _header(items.length);
                      final p = items[i - 1];
                      final title = p.name?.isNotEmpty == true
                          ? p.name!
                          : (p.code ?? 'Produit');
                      final sub = [
                        if ((p.code ?? '').isNotEmpty) 'Code: ${p.code}',
                        if ((p.barcode ?? '').isNotEmpty) 'EAN: ${p.barcode}',
                        if ((p.description ?? '').isNotEmpty) p.description!,
                      ].join('  •  ');
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            (p.name?.isNotEmpty == true
                                    ? p.name!.characters.first
                                    : (p.code ?? '?'))
                                .toUpperCase(),
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: sub.isEmpty ? null : Text(sub),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_money(p.defaultPrice)),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                switch (v) {
                                  case 'edit':
                                    _addOrEdit(existing: p);
                                    break;
                                  case 'delete':
                                    _delete(p);
                                    break;
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Modifier'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('Supprimer'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _addOrEdit(existing: p),
                      );
                    },
                  ),
        };

        return Scaffold(
          appBar: AppBar(
            title: const Text('Produits'),
            actions: [
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
  }

  Widget _header(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Produits', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text('Total: $count'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
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

  Widget _empty() {
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
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau produit'),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------ Form dialog ------------------------------ */

class _ProductFormResult {
  final String? code;
  final String? name;
  final String? description;
  final String? barcode;
  final String? categoryId;
  final int priceCents;
  const _ProductFormResult({
    this.code,
    this.name,
    this.description,
    this.barcode,
    this.categoryId,
    required this.priceCents,
  });
}

class _ProductDialog extends StatefulWidget {
  final Product? existing;
  final List<Category> categories;
  const _ProductDialog({this.existing, required this.categories});

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final TextEditingController _barcode = TextEditingController(
    text: widget.existing?.barcode ?? '',
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.existing == null
        ? ''
        : ((widget.existing!.defaultPrice) / 100).toStringAsFixed(0),
  );
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId =
        widget.existing?.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _desc.dispose();
    _barcode.dispose();
    _price.dispose();
    super.dispose();
  }

  int _toCents(String v) {
    final s = v.replaceAll(',', '.').replaceAll(' ', '');
    final d = double.tryParse(s) ?? 0;
    return (d * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Modifier le produit' : 'Nouveau produit'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
                autofocus: true,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'Code (SKU)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _barcode,
                decoration: const InputDecoration(
                  labelText: 'Code barre (EAN/UPC)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _categoryId,
                items: widget.categories
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.code)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Prix par défaut (ex: 1500)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _desc,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _ProductFormResult(
                code: _code.text.trim(),
                name: _name.text.trim(),
                description: _desc.text.trim(),
                barcode: _barcode.text.trim(),
                categoryId: _categoryId,
                priceCents: _toCents(_price.text),
              ),
            );
          },
          child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
        ),
      ],
    );
  }
}
