import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

class ProductFormResult {
  final String? code;
  final String name; // will be "No name" if left empty in the form
  final String? description;
  final String? barcode;
  final String? categoryId;
  final int priceCents; // prix de vente (obligatoire)
  final int purchasePriceCents; // prix d'achat (optionnel; default 0)

  const ProductFormResult({
    this.code,
    required this.name,
    this.description,
    this.barcode,
    this.categoryId,
    required this.priceCents,
    this.purchasePriceCents = 0, // ✅ keeps older call sites working
  });
}

class ProductFormPanel extends StatefulWidget {
  final Product? existing;
  final List<Category> categories;
  const ProductFormPanel({super.key, this.existing, required this.categories});

  @override
  State<ProductFormPanel> createState() => _ProductFormPanelState();
}

class _ProductFormPanelState extends State<ProductFormPanel> {
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

  /// Prix de vente (obligatoire)
  late final TextEditingController _priceSell = TextEditingController(
    text: widget.existing == null
        ? ''
        : _moneyFromCents(widget.existing!.defaultPrice),
  );

  /// Prix d'achat / coût (optionnel). If your Product entity does not yet
  /// carry a stored purchase price, leave this empty – it will resolve to 0.
  late final TextEditingController _priceBuy = TextEditingController(
    text: '', // fill from existing if/when you add the field to Product
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
    _priceSell.dispose();
    _priceBuy.dispose();
    super.dispose();
  }

  // --- helpers --------------------------------------------------------------

  // Display helper (integer cents -> plain string, no symbol)
  String _moneyFromCents(int cents) {
    final v = cents / 100.0;
    // No symbol, no decimals (to match your previous behavior)
    return NumberFormat.currency(symbol: '', decimalDigits: 0).format(v).trim();
  }

  // Parse helper (string -> integer cents)
  int _toCents(String v) {
    final s = v.replaceAll(',', '.').replaceAll(' ', '');
    final d = double.tryParse(s) ?? 0;
    final cents = (d * 100).round();
    return cents < 0 ? 0 : cents;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final nameValue = _name.text.trim().isEmpty ? 'No name' : _name.text.trim();

    final result = ProductFormResult(
      code: _code.text.trim().isEmpty ? null : _code.text.trim(),
      name: nameValue, // ✅ fallback if empty
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      categoryId: _categoryId,
      priceCents: _toCents(_priceSell.text), // required
      purchasePriceCents: _toCents(_priceBuy.text), // optional (0 if blank)
    );

    Navigator.pop(context, result);
  }

  // Simple required validator used only for selling price
  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requis' : null;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier le produit' : 'Nouveau produit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check),
            label: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Prix (vente) obligatoire
            TextFormField(
              controller: _priceSell,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              decoration: const InputDecoration(
                labelText: 'Prix de vente (ex: 1500)',
                helperText: 'Obligatoire',
                border: OutlineInputBorder(),
              ),
              validator: _required,
              autofocus: true,
            ),
            const SizedBox(height: 12),

            // --- Prix d'achat optionnel
            TextFormField(
              controller: _priceBuy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              decoration: const InputDecoration(
                labelText: "Prix d'achat / coût (ex: 1200)",
                helperText: "Optionnel — laissé vide = 0",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // --- Informations générales (toutes optionnelles)
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nom (laisser vide = "No name")',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _code,
              decoration: const InputDecoration(
                labelText: 'Code (SKU)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _barcode,
              decoration: const InputDecoration(
                labelText: 'Code barre (EAN/UPC)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

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
            const SizedBox(height: 12),

            TextFormField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),
            Text(
              'Astuce : utilisez la recherche pour retrouver rapidement par nom, code ou EAN.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
