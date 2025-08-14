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

        // If there are item lines, default to "lock amount to items"
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
      child: CategoryFormPanel(
        existing: null,
        // If your CategoryFormPanel supports a forced type prop, pass it here.
        // forcedTypeEntry: isDebit ? 'DEBIT' : 'CREDIT',
      ),
      widthFraction: 0.86,
      heightFraction: 0.92,
    );
    if (res == null) return;

    // Persist via repo
    final repo = ref.read(categoryRepoProvider);
    final now = DateTime.now();
    final cat = Category(
      id: const Uuid().v4(),
      code: res.code,
      description: res.description,
      typeEntry: res.typeEntry, // trust panel; you can enforce here if needed
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      remoteId: null,
      syncAt: null,
      version: 0,
      isDirty: true,
    );
    await repo.create(cat);

    // Update local lists and select if type matches current entry type
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
      child: const CustomerFormPanel(),
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
      version: (widget.entry.version ?? 0) + 1,
    );

    // Note: This updates transaction header only. If your domain supports updating
    // lines + stock, call your dedicated usecase here instead of repo.update.
    await ref.read(transactionRepoProvider).update(updated);

    if (mounted) Navigator.of(context).pop(true);
  }

  // ---------------------------------- UI -------------------------------------
  @override
  Widget build(BuildContext context) {
    final accent = isDebit
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    final typeLabel = isDebit ? 'Dépense' : 'Revenu';

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
                // Type header
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: accent,
                  ),
                  title: Text(
                    typeLabel,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text('Type de transaction'),
                ),
                const Divider(height: 24),

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
                  style: Theme.of(context).textTheme.headlineMedium,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Montant',
                    helperText: 'Exemple : 1 500 ou 1500,00',
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
                    style: Theme.of(context).textTheme.bodySmall,
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
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Catégorie',
                              isDense: true,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Tiers',
                          style: Theme.of(context).textTheme.titleMedium,
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
                              ? 'Selection des produits'
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
