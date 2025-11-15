// Product form with robust Quantity input: +/- controls, keyboard arrows,
// keeps 0 values if the user sets it, BUT default is 1 for new products.
// Default status is PUBLISH for new products.
// UI/UX improvements:
// - Primary "Enregistrer" action in the AppBar (top-right) with loading state
// - Clear section headers, helper texts, and subtle spacing
// - ChoiceChip selector for status (faster than a dropdown)
// - Sticky bottom bar kept for large screens / one-handed use
// - Better focus traversal and Enter-to-save shortcut

import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/products/entities/product.dart';
import 'package:jaayko/domain/categories/entities/category.dart';
import 'package:jaayko/domain/company/entities/company.dart';
import 'package:jaayko/domain/company/repositories/company_repository.dart';
import 'package:jaayko/presentation/app/providers/company_repo_provider.dart';
import 'package:jaayko/presentation/features/transactions/widgets/amount_field_quickpad.dart';
import '../../../widgets/attachments_picker.dart';

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
  final String? companyId;
  final String? levelId;
  final int quantity;
  final bool hasSold;
  final bool hasPrice;

  const ProductFormResult({
    this.code,
    required this.name,
    this.description,
    this.barcode,
    this.categoryId,
    required this.priceCents,
    this.purchasePriceCents = 0,
    this.status = 'ACTIVE', // ← default PUBLISH
    this.files = const [],
    this.companyId,
    this.levelId,
    this.quantity = 1, // ← default 1
    this.hasSold = false,
    this.hasPrice = false,
  });
}

class SubmitFormIntent extends Intent {
  const SubmitFormIntent();
}

class ProductFormPanel extends ConsumerStatefulWidget {
  final Product? existing;
  final List<Category> categories;
  const ProductFormPanel({super.key, this.existing, required this.categories});
  @override
  ConsumerState<ProductFormPanel> createState() => _ProductFormPanelState();
}

class _ProductFormPanelState extends ConsumerState<ProductFormPanel> {
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
  late final TextEditingController _levelId = TextEditingController(
    text: widget.existing?.levelId ?? '',
  );
  late final TextEditingController _quantity = TextEditingController(
    // default 1 if new, else existing quantity
    text: (widget.existing?.quantity ?? 1).toString(),
  );

  bool _hasSold = false;
  bool _hasPrice = false;
  bool _saving = false;

  final _fName = FocusNode();
  final _fCode = FocusNode();
  final _fBarcode = FocusNode();
  final _fDesc = FocusNode();
  final _fPriceBuy = FocusNode();
  final _fCompany = FocusNode();
  final _fLevel = FocusNode();
  final _fQuantity = FocusNode();

  String? _categoryId;
  String _status = 'ACTIVE'; // default PUBLISH if new
  String? _companyId;
  List<PickedAttachment> _files = const [];

  static const List<(String, String)> _statusOptions = <(String, String)>[
    ('ACTIVE', 'Local'),
    ('PUBLISH', 'À publier'),
    ('UNPUBLISH', 'Retiré'),
  ];

  static final _numFilter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9\\., \\u00A0\\u202F]'),
  );
  static final _intFilter = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));

  @override
  void initState() {
    super.initState();

    _categoryId =
        widget.existing?.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);

    // If editing: normalize from existing; else defaults already set above.
    if (widget.existing != null) {
      _status = _normalizeStatus(widget.existing?.statuses ?? 'PUBLISH');
      _hasSold = (widget.existing?.hasSold ?? 0) == 1;
      _hasPrice = (widget.existing?.hasPrice ?? 0) == 1;
      _companyId = widget.existing?.company;
      _quantity.text = (widget.existing?.quantity ?? 1).toString();
    } else {
      _status = 'PUBLISH';
      _hasSold = false;
      _hasPrice = false;
      _quantity.text = '1';
    }

    dev.log(
      'ProductFormPanel init status=$_status cat=$_categoryId company=$_companyId qty=${_quantity.text}',
      name: 'ProductFormPanel',
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _desc.dispose();
    _barcode.dispose();
    _priceSell.dispose();
    _priceBuy.dispose();
    _levelId.dispose();
    _quantity.dispose();
    _fName.dispose();
    _fCode.dispose();
    _fBarcode.dispose();
    _fDesc.dispose();
    _fPriceBuy.dispose();
    _fCompany.dispose();
    _fLevel.dispose();
    _fQuantity.dispose();
    super.dispose();
  }

  String _normalizeStatus(String v) {
    final codes = _statusOptions.map((e) => e.$1).toSet();
    final up = v.trim().toUpperCase();
    return codes.contains(up) ? up : 'PUBLISH';
  }

  String _moneyFromCents(int cents) {
    final v = cents / 100.0;
    return NumberFormat.currency(symbol: '', decimalDigits: 0).format(v).trim();
  }

  String _sanitizeNumber(String v) {
    var s = v.trim();
    s = s.replaceAll(RegExp(r'[\u00A0\u202F\s]'), '');
    s = s.replaceAll(',', '.');
    final firstDot = s.indexOf('.');
    final lastDot = s.lastIndexOf('.');
    if (firstDot != -1 && firstDot != lastDot) {
      s = s.replaceAll('.', '');
      if (lastDot != -1 && lastDot < s.length) {
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

  Future<List<Company>> _loadCompanies() async {
    final repo = ref.read(companyRepoProvider);
    final all = await repo.findAll(const CompanyQuery(limit: 200, offset: 0));
    final list = all
        .where((c) => (c.remoteId ?? '').trim().isNotEmpty)
        .toList();
    if (_companyId == null && list.isNotEmpty) {
      try {
        final def = list.firstWhere((c) => c.isDefault == true);
        _companyId = def.id;
      } catch (_) {
        _companyId = list.first.id;
      }
      if (mounted) setState(() {});
    }
    return list;
  }

  void _setQuantity(int q) {
    if (q < 0) q = 0;
    _quantity.text = q.toString();
    _quantity.selection = TextSelection.fromPosition(
      TextPosition(offset: _quantity.text.length),
    );
    setState(() {});
  }

  void _incQuantity(int delta) {
    final current = int.tryParse(_quantity.text.trim()) ?? 0;
    _setQuantity(current + delta);
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

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
      status: _status, // will be PUBLISH by default for new
      files: _files,
      companyId: (_companyId ?? '').isEmpty ? null : _companyId,
      levelId: _levelId.text.trim().isEmpty ? null : _levelId.text.trim(),
      quantity: int.tryParse(_quantity.text.trim()) ?? 0,
      hasSold: _hasSold,
      hasPrice: _hasPrice,
    );

    dev.log(
      'submit name=${result.name} price=${result.priceCents} qty=${result.quantity} status=${result.status} files=${result.files.length}',
      name: 'ProductFormPanel',
    );

    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const SubmitFormIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const SubmitFormIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS):
            const SubmitFormIntent(), // ⌘S / Ctrl+S on desktop
      },
      child: Actions(
        actions: {
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
              onPressed: _saving ? null : () => Navigator.pop(context),
              tooltip: 'Fermer',
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: FutureBuilder<List<Company>>(
              future: _loadCompanies(),
              builder: (context, snap) {
                final companies = snap.data ?? const <Company>[];
                final busy = snap.connectionState == ConnectionState.waiting;
                final safeCompanyId =
                    (_companyId != null &&
                        companies.any((c) => c.id == _companyId))
                    ? _companyId
                    : null;

                return Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      // ====== PRIX DE VENTE ======
                      Text(
                        'Prix & coût',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
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
                          helperText: 'Coût d’acquisition (FCFA).',
                        ),
                        enabled: !_saving,
                      ),

                      const SizedBox(height: 20),
                      // ====== IDENTITÉ ======
                      Text(
                        'Identité',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        focusNode: _fName,
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _fCode.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Nom du produit',
                        ),
                        validator: _required,
                        enabled: !_saving,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        focusNode: _fCode,
                        controller: _code,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _fBarcode.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Code (SKU)',
                          helperText: 'Laissez vide pour ignorer.',
                        ),
                        validator: _validateSku,
                        enabled: !_saving,
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
                        enabled: !_saving,
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
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _categoryId = v),
                        decoration: const InputDecoration(
                          labelText: 'Catégorie',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        focusNode: _fDesc,
                        controller: _desc,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _fCompany.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          helperText:
                              'Quelques mots pour présenter le produit.',
                        ),
                        enabled: !_saving,
                      ),

                      const SizedBox(height: 20),
                      // ====== ÉTAT & SOCIÉTÉ ======
                      Text(
                        'État & société',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _statusOptions.map((opt) {
                          final selected = _status == opt.$1;
                          return ChoiceChip(
                            label: Text(opt.$2),
                            selected: selected,
                            onSelected: _saving
                                ? null
                                : (v) {
                                    if (!v) return;
                                    setState(() => _status = opt.$1);
                                  },
                            avatar: selected
                                ? const Icon(Icons.check, size: 18)
                                : null,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        key: ValueKey(safeCompanyId),
                        focusNode: _fCompany,
                        value: safeCompanyId,
                        isDense: true,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— Aucune —'),
                          ),
                          ...companies.map(
                            (c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text('${c.name} (${c.code})'),
                            ),
                          ),
                        ],
                        onChanged: (_saving || busy)
                            ? null
                            : (v) => setState(() => _companyId = v),
                        decoration: const InputDecoration(labelText: 'Société'),
                      ),

                      const SizedBox(height: 12),
                      TextFormField(
                        focusNode: _fLevel,
                        controller: _levelId,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _fQuantity.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Niveau (levelId)',
                          helperText: 'Identifiant de niveau, optionnel.',
                        ),
                        enabled: !_saving,
                      ),

                      const SizedBox(height: 12),
                      // ====== QUANTITÉ ======
                      Text(
                        'Stock',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const ValueKey('quantityField'),
                              focusNode: _fQuantity,
                              controller: _quantity,
                              keyboardType: TextInputType.number,
                              inputFormatters: [_intFilter],
                              textInputAction: TextInputAction.done,
                              onEditingComplete: () {
                                final v =
                                    int.tryParse(_quantity.text.trim()) ?? 0;
                                _setQuantity(v);
                              },
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Quantité',
                                helperText:
                                    'Par défaut 1 pour les nouveaux produits.',
                              ),
                              enabled: !_saving,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: '—1',
                            child: IconButton.filledTonal(
                              onPressed: _saving
                                  ? null
                                  : () => _incQuantity(-1),
                              icon: const Icon(Icons.remove),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: '+1',
                            child: IconButton.filledTonal(
                              onPressed: _saving ? null : () => _incQuantity(1),
                              icon: const Icon(Icons.add),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Déjà vendu (hasSold)'),
                        value: _hasSold,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _hasSold = v),
                      ),
                      SwitchListTile(
                        title: const Text('Possède un prix (hasPrice)'),
                        value: _hasPrice,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _hasPrice = v),
                      ),

                      const SizedBox(height: 20),
                      // ====== FICHIERS ======
                      Text(
                        'Pièces jointes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      MediaAttachmentsPicker(
                        maxCount: 20,
                        maxBytes: 15 * 1024 * 1024,
                        onChanged: (items) {
                          _files = items;
                          dev.log(
                            'attachments changed count=${items.length}',
                            name: 'ProductFormPanel',
                          );
                        },
                        onError: (m) => dev.log(
                          'attachments error $m',
                          name: 'ProductFormPanel',
                        ),
                        // Enabled state handled internally; form still readable while saving.
                      ),

                      const SizedBox(height: 12),
                      Text(
                        'Astuce : Entrée pour enregistrer. Sur desktop, essayez Ctrl/⌘ + S.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
