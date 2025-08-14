// Product form right-drawer panel with purchase price and single-string status; robust number parsing and Enter submit.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

class ProductFormResult {
  final String? code;
  final String name;
  final String? description;
  final String? barcode;
  final String? categoryId;
  final int priceCents;
  final int purchasePriceCents;
  final String status;

  const ProductFormResult({
    this.code,
    required this.name,
    this.description,
    this.barcode,
    this.categoryId,
    required this.priceCents,
    this.purchasePriceCents = 0,
    this.status = 'ACTIVE',
  });
}

class SubmitFormIntent extends Intent {
  const SubmitFormIntent();
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

  // Controllers
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
  late final TextEditingController _priceSell = TextEditingController(
    text: widget.existing == null
        ? ''
        : _moneyFromCents(widget.existing!.defaultPrice),
  );
  late final TextEditingController _priceBuy = TextEditingController(
    text: widget.existing == null
        ? ''
        : _moneyFromCents(widget.existing!.purchasePrice),
  );

  // Focus chain
  final _fPriceBuy = FocusNode();
  final _fName = FocusNode();
  final _fCode = FocusNode();
  final _fBarcode = FocusNode();
  final _fDesc = FocusNode();

  String? _categoryId;
  String _status = 'ACTIVE';

  static const List<(String, String)> _statusOptions = [
    ('ACTIVE', 'Actif'),
    ('PROMO', 'Promotion'),
    ('ARCHIVED', 'Archivé'),
  ];

  // Accept digits, dot, comma, normal spaces and NBSP variants
  static final _numFilter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9\.\, \u00A0\u202F]'),
  );

  @override
  void initState() {
    super.initState();
    _categoryId =
        widget.existing?.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    _status = widget.existing?.statuses ?? 'ACTIVE';
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _desc.dispose();
    _barcode.dispose();
    _priceSell.dispose();
    _priceBuy.dispose();
    _fPriceBuy.dispose();
    _fName.dispose();
    _fCode.dispose();
    _fBarcode.dispose();
    _fDesc.dispose();
    super.dispose();
  }

  String _moneyFromCents(int cents) {
    final v = cents / 100.0;
    // Keep 0 decimals to match your UX: user types "1500" for 1500 units
    return NumberFormat.currency(symbol: '', decimalDigits: 0).format(v).trim();
  }

  // --- robust number sanitizer ------------------------------------------------
  // 1) remove all spaces including NBSP (\u00A0) and NNBSP (\u202F)
  // 2) convert comma to dot for decimals
  // 3) if multiple dots exist, treat them as thousand separators -> remove all dots
  String _sanitizeNumber(String v) {
    var s = v.trim();
    s = s.replaceAll(RegExp(r'[\u00A0\u202F\s]'), ''); // all kinds of spaces
    s = s.replaceAll(',', '.'); // unify decimal sep
    final firstDot = s.indexOf('.');
    final lastDot = s.lastIndexOf('.');
    if (firstDot != -1 && firstDot != lastDot) {
      // multiple dots -> consider them as grouping; remove all
      s = s.replaceAll('.', '');
    }
    return s;
  }

  int _toCents(String v) {
    final s = _sanitizeNumber(v);
    final d = double.tryParse(s) ?? 0;
    final cents = (d * 100).round();
    return cents < 0 ? 0 : cents;
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Requis' : null;

  InputDecoration _dec(
    String label, {
    String? helper,
    String? hint,
    TextEditingController? ctrl,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      suffixIcon: (ctrl == null || ctrl.text.isEmpty)
          ? null
          : IconButton(
              tooltip: 'Effacer',
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => ctrl.clear()),
            ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final nameValue = _name.text.trim().isEmpty ? 'No name' : _name.text.trim();

    final result = ProductFormResult(
      code: _code.text.trim().isEmpty ? null : _code.text.trim(),
      name: nameValue,
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      categoryId: _categoryId,
      priceCents: _toCents(_priceSell.text),
      purchasePriceCents: _priceBuy.text.trim().isEmpty
          ? 0
          : _toCents(_priceBuy.text),
      status: _status,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const SubmitFormIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const SubmitFormIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SubmitFormIntent: CallbackAction<SubmitFormIntent>(
            onInvoke: (_) {
              _submit();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEdit ? 'Modifier le produit' : 'Nouveau produit'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Fermer',
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
          body: SafeArea(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Prix de vente (requis)
                  TextFormField(
                    controller: _priceSell,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    inputFormatters: [_numFilter],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _fPriceBuy.requestFocus(),
                    decoration: _dec(
                      'Prix de vente (ex: 1500)',
                      helper: 'Obligatoire',
                      ctrl: _priceSell,
                    ),
                    validator: _required,
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),

                  // Prix d'achat (optionnel)
                  TextFormField(
                    focusNode: _fPriceBuy,
                    controller: _priceBuy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    inputFormatters: [_numFilter],
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _fName.requestFocus(),
                    decoration: _dec(
                      "Prix d'achat / coût (ex: 1200)",
                      helper: 'Optionnel',
                      ctrl: _priceBuy,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nom
                  TextFormField(
                    focusNode: _fName,
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _fCode.requestFocus(),
                    decoration: _dec(
                      'Nom (laisser vide = "No name")',
                      ctrl: _name,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Code
                  TextFormField(
                    focusNode: _fCode,
                    controller: _code,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _fBarcode.requestFocus(),
                    decoration: _dec('Code (SKU)', ctrl: _code),
                  ),
                  const SizedBox(height: 12),

                  // Code barre
                  TextFormField(
                    focusNode: _fBarcode,
                    controller: _barcode,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _fDesc.requestFocus(),
                    decoration: _dec('Code barre (EAN/UPC)', ctrl: _barcode),
                  ),
                  const SizedBox(height: 12),

                  // Catégorie
                  DropdownButtonFormField<String>(
                    value: _categoryId,
                    items: widget.categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.code),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    decoration: _dec('Catégorie'),
                  ),
                  const SizedBox(height: 12),

                  // Statut
                  DropdownButtonFormField<String>(
                    value: _status,
                    items: _statusOptions
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e.$1, child: Text(e.$2)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
                    decoration: _dec('Statut'),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    focusNode: _fDesc,
                    controller: _desc,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: _dec('Description', ctrl: _desc),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    'Astuce : appuyez sur Entrée pour enregistrer rapidement.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
