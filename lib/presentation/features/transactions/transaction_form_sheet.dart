// lib/presentation/features/transactions/transaction_form_sheet.dart
// Edit a transaction: category (create/select), company & customer (reload + create & auto-select),
// product lines (picker + amount lock), robust amount parsing, Enter-to-save, overflow-safe UI.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/features/transactions/providers/transaction_detail_providers.dart';

import '../../../domain/company/repositories/company_repository.dart';
import '../../../domain/customer/repositories/customer_repository.dart';
import '../../app/providers/company_repo_provider.dart';
import '../../app/providers/customer_repo_provider.dart';
import '../../widgets/right_drawer.dart';

// Inline create panels
import '../customers/customer_create_panel.dart';
import '../customers/customer_form_panel.dart';
import '../../features/categories/widgets/category_form_panel.dart'
    show CategoryFormPanel, CategoryFormResult;

// Products
import '../products/product_picker_panel.dart';
import '../products/product_repo_provider.dart';
import '../products/widgets/product_form_panel.dart'
    show ProductFormPanel, ProductFormResult;
import '../../../domain/products/entities/product.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  final TransactionEntry entry;
  const TransactionFormSheet({super.key, required this.entry});

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final formKey = GlobalKey<FormState>();
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  late final bool isDebit = widget.entry.typeEntry == 'DEBIT';
  late final _Tone tone = _toneForType(context, widget.entry.typeEntry);

  DateTime when = DateTime.now();

  String? categoryId;
  String? companyId;
  String? customerId;

  List<Category> _allCategories = const [];
  List<Company> _companies = const [];
  List<Customer> _customers = const [];

  final List<_TxItem> _items = [];
  bool _lockAmountToItems = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    amountCtrl.text = _moneyFromCents(e.amount);
    descCtrl.text = e.description ?? '';
    categoryId = e.categoryId;
    when = e.dateTransaction;
    companyId = e.companyId;
    customerId = e.customerId;
    _bootstrap();
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  // ------------------------------ bootstrap ----------------------------------
  Future<void> _bootstrap() async {
    try {
      final catRepo = ref.read(categoryRepoProvider);
      final coRepo = ref.read(companyRepoProvider);
      final cuRepo = ref.read(customerRepoProvider);

      final cats = await catRepo.findAllActive();
      final cos = await coRepo.findAll(
        const CompanyQuery(limit: 300, offset: 0),
      );
      final cus = await cuRepo.findAll(
        CustomerQuery(
          companyId: (companyId ?? '').isEmpty ? null : companyId,
          limit: 300,
          offset: 0,
        ),
      );

      // Load previously saved lines (products)
      final saved = await ref.read(
        transactionItemsProvider(widget.entry.id).future,
      );

      if (!mounted) return;
      setState(() {
        _allCategories = cats;
        _companies = cos;
        _customers = cus;

        _items
          ..clear()
          ..addAll(
            saved
                .where((it) => it.productId != null)
                .map(
                  (it) => _TxItem(
                    productId: it.productId!,
                    label: (it.label ?? '').isEmpty ? 'Produit' : it.label!,
                    unitPriceCents: it.unitPrice,
                    quantity: it.quantity,
                  ),
                ),
          );

        _lockAmountToItems = _items.isNotEmpty;
        if (_lockAmountToItems) _syncAmountFromItems();

        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ------------------------------ helpers ------------------------------------
  String _moneyFromCents(int cents) => (cents / 100).toStringAsFixed(2);

  String _sanitizeAmount(String v) {
    // remove spaces and NBSPs, normalize comma to dot; collapse thousand separators
    var s = v
        .trim()
        .replaceAll(RegExp(r'[\u00A0\u202F\s]'), '')
        .replaceAll(',', '.');
    final firstDot = s.indexOf('.');
    final lastDot = s.lastIndexOf('.');
    if (firstDot != -1 && firstDot != lastDot) {
      s = s.replaceAll('.', ''); // multiple dots -> treat as grouping
    }
    return s;
  }

  int _toCents(String v) {
    final s = _sanitizeAmount(v);
    final d = double.tryParse(s) ?? 0;
    final c = (d * 100).round();
    return c < 0 ? 0 : c;
  }

  String get _amountPreview =>
      Formatters.amountFromCents(_toCents(amountCtrl.text));

  List<Category> _filteredCatsForType() {
    final t = isDebit ? 'DEBIT' : 'CREDIT';
    return _allCategories.where((c) => c.typeEntry == t).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        when = DateTime(
          picked.year,
          picked.month,
          picked.day,
          when.hour,
          when.minute,
          when.second,
          when.millisecond,
          when.microsecond,
        );
      });
    }
  }

  Future<void> _onSelectCompany(String? id) async {
    setState(() {
      companyId = id;
      customerId = null;
      _customers = const [];
    });
    try {
      final cuRepo = ref.read(customerRepoProvider);
      final list = await cuRepo.findAll(
        CustomerQuery(
          companyId: (id ?? '').isEmpty ? null : id,
          limit: 300,
          offset: 0,
        ),
      );
      if (!mounted) return;
      setState(() => _customers = list);
    } catch (_) {}
  }

  int get _itemsTotalCents =>
      _items.fold(0, (sum, it) => sum + (it.unitPriceCents * it.quantity));

  void _syncAmountFromItems() {
    final total = _itemsTotalCents;
    amountCtrl.text = (total / 100).toStringAsFixed(2);
    setState(() {});
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ----------------------- inline create flows --------------------------------
  Future<void> _createCategoryAndSelect() async {
    final res = await showRightDrawer<CategoryFormResult?>(
      context,
      child: CategoryFormPanel(existing: null),
      widthFraction: 0.86,
      heightFraction: 0.92,
    );
    if (res == null) return;

    final repo = ref.read(categoryRepoProvider);
    final now = DateTime.now();
    final cat = Category(
      id: const Uuid().v4(),
      code: res.code,
      description: res.description,
      typeEntry: res.typeEntry,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      remoteId: null,
      syncAt: null,
      version: 0,
      isDirty: true,
    );
    await repo.create(cat);

    final isSameType = cat.typeEntry == (isDebit ? 'DEBIT' : 'CREDIT');
    setState(() {
      _allCategories = [cat, ..._allCategories];
      categoryId = isSameType ? cat.id : categoryId;
    });
    _snack(
      isSameType
          ? 'Catégorie créée et sélectionnée'
          : 'Catégorie créée (type différent – non sélectionnée)',
    );
  }

  Future<void> _createCustomerAndSelect() async {
    final created = await showRightDrawer<Customer?>(
      context,
      child: const CustomerCreatePanel(),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (created == null) return;

    final targetCompanyId = created.companyId ?? companyId;
    setState(() => companyId = targetCompanyId);

    try {
      if (targetCompanyId != null && targetCompanyId.isNotEmpty) {
        final list = await ref
            .read(customerRepoProvider)
            .findAll(
              CustomerQuery(companyId: targetCompanyId, limit: 300, offset: 0),
            );
        if (!mounted) return;
        setState(() {
          _customers = list;
          customerId = _customers.any((c) => c.id == created.id)
              ? created.id
              : null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          if (!_customers.any((c) => c.id == created.id)) {
            _customers = [created, ..._customers];
          }
          customerId = created.id;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!_customers.any((c) => c.id == created.id)) {
          _customers = [created, ..._customers];
        }
        customerId = created.id;
      });
    }

    _snack('Client créé et sélectionné');
  }

  Future<void> _openProductPicker() async {
    final initial = _items
        .map(
          (e) => {
            'productId': e.productId,
            'label': e.label,
            'unitPriceCents': e.unitPriceCents,
            'quantity': e.quantity,
          },
        )
        .toList();

    final result = await showRightDrawer(
      context,
      child: ProductPickerPanel(initialLines: initial),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    if (!mounted) return;
    if (result is! List) return;

    final List<_TxItem> parsed = [];
    for (final e in result) {
      if (e is Map) {
        final id = e['productId'] as String?;
        final label = (e['label'] as String?) ?? '';
        final unit =
            (e['unitPriceCents'] as int?) ?? (e['unitPrice'] as int?) ?? 0;
        final qty = (e['quantity'] as int?) ?? 1;
        if (id != null) {
          parsed.add(
            _TxItem(
              productId: id,
              label: label,
              unitPriceCents: unit,
              quantity: qty,
            ),
          );
        }
      }
    }
    setState(() {
      _items
        ..clear()
        ..addAll(parsed);
      _lockAmountToItems = true;
    });
    _syncAmountFromItems();
  }

  Future<void> _createProductAndAddLine() async {
    final categories = await ref.read(categoryRepoProvider).findAllActive();
    if (!mounted) return;

    final formRes = await showRightDrawer<ProductFormResult?>(
      context,
      child: ProductFormPanel(existing: null, categories: categories),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    if (formRes == null) return;

    // persist product
    final repo = ref.read(productRepoProvider);
    final now = DateTime.now();
    final p = Product(
      id: const Uuid().v4(),
      remoteId: null,
      code: formRes.code,
      name: formRes.name,
      description: formRes.description,
      barcode: formRes.barcode,
      unitId: null,
      categoryId: formRes.categoryId,
      defaultPrice: formRes.priceCents,
      purchasePrice: formRes.purchasePriceCents,
      statuses: formRes.status,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncAt: null,
      version: 0,
      isDirty: 1,
    );
    await repo.create(p);

    setState(() {
      _items.add(
        _TxItem(
          productId: p.id,
          label: (p.name?.isNotEmpty ?? false)
              ? p.name!
              : (p.code ?? 'Produit'),
          unitPriceCents: p.defaultPrice,
          quantity: 1,
        ),
      );
      _lockAmountToItems = true;
    });
    _syncAmountFromItems();
    _snack('Produit créé et ajouté');
  }

  // --------------------------------- save ------------------------------------
  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;

    final cents = _toCents(amountCtrl.text);
    if (cents <= 0) {
      _snack('Le montant doit être supérieur à 0');
      return;
    }

    final updated = widget.entry.copyWith(
      amount: cents,
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      categoryId: categoryId,
      dateTransaction: when,
      companyId: companyId,
      customerId: customerId,
      updatedAt: DateTime.now(),
      isDirty: true,
      version: (widget.entry.version) + 1,
    );

    // Note: This updates transaction header only.
    await ref.read(transactionRepoProvider).update(updated);

    if (mounted) Navigator.of(context).pop(true);
  }

  // ---------------------------------- UI -------------------------------------
  @override
  Widget build(BuildContext context) {
    final accent = tone.color;
    final typeLabel = tone.label;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const _SubmitIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _SubmitIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SubmitIntent: CallbackAction<_SubmitIntent>(
            onInvoke: (_) {
              _save();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text('Modifier la ${typeLabel.toLowerCase()}'),
            leading: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              IconButton(
                tooltip: 'Enregistrer',
                icon: const Icon(Icons.check),
                onPressed: _save,
              ),
            ],
            bottom: _loading
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                : null,
          ),
          body: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                _HeaderToneCard(
                  tone: tone,
                  when: when,
                  onTapDate: _pickDate,
                  hasItems: _items.isNotEmpty,
                  accountless: (widget.entry.accountId ?? '').isEmpty,
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9\.\,\u00A0\u202F\s]'),
                    ),
                  ],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: accent, width: 1.8),
                    ),
                    labelText: 'Montant',
                    helperText: 'Exemple : 1 500 ou 1500,00',
                    prefixIcon: Icon(
                      Icons.payments_rounded,
                      color: accent.withOpacity(0.9),
                    ),
                    suffixIcon: amountCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer',
                            onPressed: () {
                              amountCtrl.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                    filled: true,
                    fillColor: accent.withOpacity(0.05),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requis';
                    final cents = _toCents(v);
                    if (cents <= 0) return 'Montant invalide';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Aperçu: $_amountPreview',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: accent),
                  ),
                ),

                if (_items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Verrouiller le montant sur le total des articles',
                    ),
                    value: _lockAmountToItems,
                    onChanged: (v) {
                      setState(() {
                        _lockAmountToItems = v;
                        if (v) _syncAmountFromItems();
                      });
                    },
                    secondary: Icon(Icons.link_rounded, color: accent),
                  ),
                ],

                const SizedBox(height: 12),

                // Category (overflow-safe + "create" shortcut)
                Builder(
                  builder: (context) {
                    final filtered = _filteredCatsForType();
                    final items = <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('— Aucune —'),
                      ),
                      ...filtered.map(
                        (c) => DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(
                            '${c.code}${(c.description ?? '').isNotEmpty ? ' — ${c.description}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ];
                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: categoryId,
                            items: items,
                            isDense: true,
                            isExpanded: true,
                            selectedItemBuilder: (ctx) => items
                                .map(
                                  (e) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: e.child is Text
                                        ? Text(
                                            (e.child as Text).data ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => categoryId = v),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              labelText: 'Catégorie',
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.category_outlined,
                                color: accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Créer une catégorie',
                          child: IconButton(
                            onPressed: _createCategoryAndSelect,
                            icon: const Icon(Icons.add),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Parties (Company & Customer, with "create customer")
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.group_outlined, color: accent),
                            const SizedBox(width: 8),
                            Text(
                              'Tiers',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(width: 8),
                            if ((companyId ?? '').isNotEmpty)
                              _TypePillSmall(
                                label: 'Société liée',
                                color: accent,
                              ),
                            if ((customerId ?? '').isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _TypePillSmall(
                                label: 'Client lié',
                                color: accent,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          value: companyId,
                          isDense: true,
                          isExpanded: true,
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('— Aucune société —'),
                            ),
                            ..._companies.map(
                              (co) => DropdownMenuItem<String?>(
                                value: co.id,
                                child: Text(
                                  '${co.name} (${co.code})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          selectedItemBuilder: (ctx) => [
                            const Text(
                              '— Aucune société —',
                              overflow: TextOverflow.ellipsis,
                            ),
                            ..._companies.map(
                              (co) => Text(
                                '${co.name} (${co.code})',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                          onChanged: _onSelectCompany,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Société',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: customerId,
                                isDense: true,
                                isExpanded: true,
                                items: <DropdownMenuItem<String?>>[
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('— Aucun client —'),
                                  ),
                                  ..._customers.map(
                                    (cu) => DropdownMenuItem<String?>(
                                      value: cu.id,
                                      child: Text(
                                        cu.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                selectedItemBuilder: (ctx) => [
                                  const Text(
                                    '— Aucun client —',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  ..._customers.map(
                                    (cu) => Text(
                                      cu.fullName,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => customerId = v),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Client',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Créer un client',
                              child: IconButton(
                                onPressed: _createCustomerAndSelect,
                                icon: const Icon(Icons.person_add_alt_1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Items / Products
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openProductPicker,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: Text(
                          _items.isEmpty
                              ? 'Sélection des produits'
                              : 'Modifier les produits',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Créer un produit et l’ajouter',
                      child: IconButton(
                        onPressed: _createProductAndAddLine,
                        icon: const Icon(Icons.add_box_outlined),
                      ),
                    ),
                  ],
                ),
                if (_items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Chip(label: Text('${_items.length} produit(s)')),
                      InputChip(
                        avatar: const Icon(Icons.payments, size: 18),
                        label: Text(
                          'Total: ${Formatters.amountFromCents(_itemsTotalCents)}',
                        ),
                        onPressed: _syncAmountFromItems,
                      ),
                      IconButton(
                        tooltip: 'Vider',
                        onPressed: () {
                          setState(() {
                            _items.clear();
                            _lockAmountToItems = false;
                          });
                          _syncAmountFromItems();
                        },
                        icon: const Icon(Icons.delete_sweep),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      final lineTotal = it.unitPriceCents * it.quantity;
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.shopping_bag),
                        title: Text(
                          it.label.isEmpty ? 'Produit' : it.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Qté: ${it.quantity} • PU: ${Formatters.amountFromCents(it.unitPriceCents)}',
                        ),
                        trailing: Text(Formatters.amountFromCents(lineTotal)),
                        onTap: _openProductPicker,
                      );
                    },
                  ),
                ],

                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.notes_outlined, color: accent),
                    suffixIcon: descCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer',
                            onPressed: () {
                              descCtrl.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                  minLines: 1,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                ),

                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(Formatters.dateFull(when)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                ),

                const SizedBox(height: 8),
                SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close),
                          label: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.check),
                          label: const Text('Enregistrer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}

class _TxItem {
  final String productId;
  final String label;
  final int unitPriceCents;
  final int quantity;
  const _TxItem({
    required this.productId,
    required this.label,
    required this.unitPriceCents,
    required this.quantity,
  });
}

/// ----------------------------- UI helpers (tone / header) -----------------------------

class _HeaderToneCard extends StatelessWidget {
  final _Tone tone;
  final DateTime when;
  final VoidCallback onTapDate;
  final bool hasItems;
  final bool accountless;

  const _HeaderToneCard({
    required this.tone,
    required this.when,
    required this.onTapDate,
    required this.hasItems,
    required this.accountless,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(tone.color);
    final c1 = hsl
        .withLightness((hsl.lightness + (isDark ? 0.12 : 0.20)).clamp(0, 1))
        .toColor();
    final c2 = hsl
        .withLightness((hsl.lightness - (isDark ? 0.10 : 0.06)).clamp(0, 1))
        .toColor();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [c1.withOpacity(0.18), c2.withOpacity(0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: tone.color.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: tone.color.withOpacity(0.15),
            child: Icon(tone.icon, color: tone.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _TypePill(label: tone.label, color: tone.color),
                ActionChip(
                  avatar: const Icon(Icons.event, size: 16),
                  label: Text(Formatters.dateFull(when)),
                  onPressed: onTapDate,
                  visualDensity: VisualDensity.compact,
                ),
                if (hasItems)
                  _TypePillSmall(label: 'Articles', color: tone.color),
                if (accountless)
                  _TypePillSmall(label: 'Hors compte', color: tone.color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final Color color;
  const _TypePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(0.12);
    final fg = color.withOpacity(0.95);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fg.withOpacity(0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _TypePillSmall extends StatelessWidget {
  final String label;
  final Color color;
  const _TypePillSmall({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(0.10);
    final fg = color.withOpacity(0.90);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fg.withOpacity(0.28), width: 0.7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _Tone {
  final Color color;
  final IconData icon;
  final String label;

  _Tone({required this.color, required this.icon, required this.label});
}

_Tone _toneForType(BuildContext context, String type) {
  final scheme = Theme.of(context).colorScheme;
  final upper = type.toUpperCase();

  switch (upper) {
    case 'DEBIT':
      return _Tone(color: scheme.error, icon: Icons.south, label: 'Dépense');
    case 'CREDIT':
      return _Tone(color: scheme.tertiary, icon: Icons.north, label: 'Revenu');
    case 'REMBOURSEMENT':
      return _Tone(
        color: Colors.teal,
        icon: Icons.undo_rounded,
        label: 'Remboursement',
      );
    case 'PRET':
      return _Tone(
        color: Colors.purple,
        icon: Icons.account_balance_outlined,
        label: 'Prêt',
      );
    case 'DEBT':
      return _Tone(
        color: Colors.amber.shade800,
        icon: Icons.receipt_long,
        label: 'Dette',
      );
    default:
      return _Tone(
        color: scheme.primary,
        icon: Icons.receipt_long,
        label: upper,
      );
  }
}
