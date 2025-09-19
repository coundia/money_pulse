// Right-drawer form to create or edit a product with quick amount pad and image attachments.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/presentation/widgets/attachments_picker.dart';

import '../../transactions/widgets/amount_field_quickpad.dart';

/// What the form returns to the caller (ProductListPage).
class ProductFormResult {
  final String? code;
  final String name;
  final String? description;
  final String? barcode;
  final String? categoryId;
  final int priceCents;
  final int purchasePriceCents;
  final String status;
  final List<PickedAttachment> files;

  const ProductFormResult({
    this.code,
    required this.name,
    this.description,
    this.barcode,
    this.categoryId,
    required this.priceCents,
    this.purchasePriceCents = 0,
    this.status = 'ACTIVE',
    this.files = const [],
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

  final _fName = FocusNode();
  final _fCode = FocusNode();
  final _fBarcode = FocusNode();
  final _fDesc = FocusNode();
  final _fPriceBuy = FocusNode();

  String? _categoryId;
  String _status = 'ACTIVE';
  List<PickedAttachment> _files = const [];

  static const List<(String, String)> _statusOptions = <(String, String)>[
    ('ACTIVE', 'Actif'),
    ('PROMO', 'Promotion'),
    ('ARCHIVED', 'Archivé'),
  ];

  // Accept digits, spaces, thin spaces, comma, dot.
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

    _fName.dispose();
    _fCode.dispose();
    _fBarcode.dispose();
    _fDesc.dispose();
    _fPriceBuy.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------

  String _moneyFromCents(int cents) {
    final v = cents / 100.0;
    return NumberFormat.currency(symbol: '', decimalDigits: 0).format(v).trim();
  }

  String _sanitizeNumber(String v) {
    var s = v.trim();
    s = s.replaceAll(
      RegExp(r'[\u00A0\u202F\s]'),
      '',
    ); // remove spaces/thin spaces
    s = s.replaceAll(',', '.'); // normalize comma to dot
    // If there are multiple dots, keep the last as decimal separator.
    final firstDot = s.indexOf('.');
    final lastDot = s.lastIndexOf('.');
    if (firstDot != -1 && firstDot != lastDot) {
      s = s.replaceAll('.', '');
      if (lastDot != -1 && lastDot < s.length) {
        // put back one decimal dot before last 2 digits (best effort)
        if (s.length > 2) {
          s = s.substring(0, s.length - 2) + '.' + s.substring(s.length - 2);
        }
      }
    }
    return s;
  }

  int _toCents(String v) {
    final s = _sanitizeNumber(v);
    final d = double.tryParse(s) ?? 0.0;
    final cents = (d * 100).round();
    return cents < 0 ? 0 : cents;
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null;

  String? _validateSku(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final regex = RegExp(r'^[a-zA-Z0-9_-]{3,}$');
    if (!regex.hasMatch(v)) return 'SKU invalide (min 3 caractères)';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final result = ProductFormResult(
      code: _code.text.trim().isEmpty ? null : _code.text.trim(),
      name: _name.text.trim(),
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      categoryId: _categoryId,
      priceCents: _toCents(_priceSell.text),
      purchasePriceCents: _priceBuy.text.trim().isEmpty
          ? 0
          : _toCents(_priceBuy.text),
      status: _status,
      files: _files,
    );

    Navigator.pop(context, result);
  }

  // ---------- UI ----------

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
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check),
                      label: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Quick amount pad for selling price
                  AmountFieldQuickPad(
                    controller: _priceSell,
                    quickUnits: const [
                      0,
                      2000,
                      5000,
                      10000,
                      20000,
                      50000,
                      100000,
                      200000,
                      300000,
                      400000,
                      500000,
                      1000000,
                    ],
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    focusNode: _fName,
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _fCode.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: 'Nom du produit',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),

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
                    decoration: const InputDecoration(
                      labelText: "Prix d'achat (optionnel)",
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    focusNode: _fCode,
                    controller: _code,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _fBarcode.requestFocus(),
                    decoration: const InputDecoration(labelText: 'Code (SKU)'),
                    validator: _validateSku,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    focusNode: _fBarcode,
                    controller: _barcode,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _fDesc.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: 'Code barre (EAN/UPC)',
                    ),
                  ),
                  const SizedBox(height: 12),

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
                    decoration: const InputDecoration(labelText: 'Catégorie'),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _status,
                    items: _statusOptions
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e.$1, child: Text(e.$2)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
                    decoration: const InputDecoration(labelText: 'Statut'),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    focusNode: _fDesc,
                    controller: _desc,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Photos du produit',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  // The picker will call onChanged with the current list;
                  // ProductListPage will persist them after the form returns.
                  AttachmentsPicker(onChanged: (items) => _files = items),

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
