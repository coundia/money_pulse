/// Right-drawer product form using MediaAttachmentsPicker with logs and French UI.

import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/domain/company/repositories/company_repository.dart';
import 'package:money_pulse/presentation/app/providers/company_repo_provider.dart';
import 'package:money_pulse/presentation/features/transactions/widgets/amount_field_quickpad.dart';

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
    this.status = 'ACTIVE',
    this.files = const [],
    this.companyId,
    this.levelId,
    this.quantity = 0,
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
    text: widget.existing == null
        ? '0'
        : (widget.existing!.quantity).toString(),
  );

  bool _hasSold = false;
  bool _hasPrice = false;

  final _fName = FocusNode();
  final _fCode = FocusNode();
  final _fBarcode = FocusNode();
  final _fDesc = FocusNode();
  final _fPriceBuy = FocusNode();
  final _fCompany = FocusNode();
  final _fLevel = FocusNode();
  final _fQuantity = FocusNode();

  String? _categoryId;
  String _status = 'ACTIVE';
  String? _companyId;
  List<PickedAttachment> _files = const [];

  static const List<(String, String)> _statusOptions = <(String, String)>[
    ('ACTIVE', 'Actif'),
    ('PROMO', 'Promotion'),
    ('ARCHIVED', 'Archivé'),
    ('PUBLISH', 'À publier'),
    ('PUBLISHED', 'Publié'),
    ('UNPUBLISH', 'Retiré'),
  ];

  static final _numFilter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9\.\, \u00A0\u202F]'),
  );
  static final _intFilter = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));

  @override
  void initState() {
    super.initState();
    _categoryId =
        widget.existing?.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    _status = _normalizeStatus(widget.existing?.statuses ?? 'ACTIVE');
    _hasSold = (widget.existing?.hasSold ?? 0) == 1;
    _hasPrice = (widget.existing?.hasPrice ?? 0) == 1;
    _companyId = widget.existing?.company;
    dev.log(
      'ProductFormPanel init status=$_status cat=$_categoryId company=$_companyId',
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
    return codes.contains(up) ? up : 'ACTIVE';
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
      companyId: (_companyId ?? '').isEmpty ? null : _companyId,
      levelId: _levelId.text.trim().isEmpty ? null : _levelId.text.trim(),
      quantity: int.tryParse(_quantity.text.trim()) ?? 0,
      hasSold: _hasSold,
      hasPrice: _hasPrice,
    );
    dev.log(
      'submit name=${result.name} price=${result.priceCents} files=${result.files.length}',
      name: 'ProductFormPanel',
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const SubmitFormIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const SubmitFormIntent(),
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
                final allowedStatuses = _statusOptions
                    .map((e) => e.$1)
                    .toSet()
                    .toList();
                final safeStatus = allowedStatuses.contains(_status)
                    ? _status
                    : 'ACTIVE';

                return Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
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
                        onFieldSubmitted: (_) => _fCompany.requestFocus(),
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
                        decoration: const InputDecoration(
                          labelText: 'Code (SKU)',
                        ),
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
                        decoration: const InputDecoration(
                          labelText: 'Catégorie',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: safeStatus,
                        items: _statusOptions
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.$1,
                                child: Text(e.$2),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(
                          () => _status = _normalizeStatus(v ?? 'ACTIVE'),
                        ),
                        decoration: const InputDecoration(labelText: 'Statut'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        focusNode: _fDesc,
                        controller: _desc,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _fCompany.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 16),
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
                        onChanged: busy
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
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        focusNode: _fQuantity,
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_intFilter],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Quantité',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Déjà vendu (hasSold)'),
                        value: _hasSold,
                        onChanged: (v) => setState(() => _hasSold = v),
                      ),
                      SwitchListTile(
                        title: const Text('Possède un prix (hasPrice)'),
                        value: _hasPrice,
                        onChanged: (v) => setState(() => _hasPrice = v),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pièces jointes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      MediaAttachmentsPicker(
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
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Astuce : appuyez sur Entrée pour enregistrer rapidement.',
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
