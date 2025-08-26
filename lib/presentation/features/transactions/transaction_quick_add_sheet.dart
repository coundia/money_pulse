// Orchestrates the quick add transaction form with keyboard-safe padding and focus flow.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/products/entities/product.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/features/products/product_picker_panel.dart';
import 'package:money_pulse/presentation/features/products/product_repo_provider.dart';
import 'package:money_pulse/presentation/features/products/widgets/product_form_panel.dart';
import '../customers/customer_create_panel.dart';
import 'models/tx_item.dart';
import 'quick_add/tx_quick_add_notifier.dart';
import 'quick_add/tx_quick_utils.dart';
import 'widgets/amount_field_quickpad.dart';
import 'widgets/bottom_bar.dart';
import 'widgets/category_autocomplete.dart';
import 'widgets/date_row.dart';
import 'widgets/items_section.dart';
import 'package:money_pulse/presentation/features/customers/customer_form_panel.dart';
import 'widgets/customer_autocomplete.dart';
import 'widgets/type_selector.dart';

class TransactionQuickAddSheet extends ConsumerStatefulWidget {
  final String initialTypeEntry;
  final String? initialCustomerId;
  final String? initialCompanyId;

  const TransactionQuickAddSheet({
    super.key,
    required this.initialTypeEntry,
    this.initialCustomerId,
    this.initialCompanyId,
  });

  @override
  ConsumerState<TransactionQuickAddSheet> createState() =>
      _TransactionQuickAddSheetState();
}

class _TransactionQuickAddSheetState
    extends ConsumerState<TransactionQuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(txQuickAddProvider.notifier)
          .init(
            initialTypeEntry: widget.initialTypeEntry,
            initialCustomerId: widget.initialCustomerId,
            initialCompanyId: widget.initialCompanyId,
          );
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  Future<void> _openProductPicker() async {
    final result = await showRightDrawer(
      context,
      child: const ProductPickerPanel(),
    );
    if (!mounted) return;
    if (result is List) {
      final List<TxItem> parsed = [];
      for (final e in result) {
        if (e is Map) {
          final id = e['productId'] as String?;
          final label = (e['label'] as String?) ?? '';
          final unit =
              (e['unitPriceCents'] as int?) ?? (e['unitPrice'] as int?) ?? 0;
          final qty = (e['quantity'] as int?) ?? 1;
          if (id != null) {
            parsed.add(
              TxItem(
                productId: id,
                label: label,
                unitPriceCents: unit,
                quantity: qty,
              ),
            );
          }
        }
      }
      ref.read(txQuickAddProvider.notifier).setItems(parsed, lockToItems: true);
      if (parsed.isNotEmpty) {
        final total = parsed.fold<int>(
          0,
          (sum, it) => sum + (it.unitPriceCents * it.quantity),
        );
        _amountCtrl.text = (total / 100).toStringAsFixed(2);
        final cat = ref
            .read(txQuickAddProvider.notifier)
            .autoSelectCategoryForProducts();
        if (cat != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ref.read(txQuickAddProvider).kind == TxKind.debit
                    ? 'Catégorie Achat sélectionnée automatiquement'
                    : 'Catégorie Vente sélectionnée automatiquement',
              ),
            ),
          );
          _categoryCtrl.text = cat.code;
        }
        setState(() {});
      }
    }
  }

  Future<void> _createProductAndAddLine() async {
    final repo = ref.read(productRepoProvider);
    final categories = ref.read(txQuickAddProvider).categories;
    final res = await showRightDrawer<ProductFormResult?>(
      context,
      child: ProductFormPanel(existing: null, categories: categories),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    if (res == null) return;
    final now = DateTime.now();
    final p = Product(
      id: const Uuid().v4(),
      remoteId: null,
      code: res.code,
      name: res.name,
      description: res.description,
      barcode: res.barcode,
      unitId: null,
      categoryId: res.categoryId,
      defaultPrice: res.priceCents,
      purchasePrice: res.purchasePriceCents,
      statuses: res.status,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncAt: null,
      version: 0,
      isDirty: 1,
    );
    await repo.create(p);

    final item = TxItem(
      productId: p.id,
      label: (p.name?.isNotEmpty ?? false) ? p.name! : (p.code ?? 'Produit'),
      unitPriceCents: p.defaultPrice,
      quantity: 1,
    );
    final current = [...ref.read(txQuickAddProvider).items, item];
    ref.read(txQuickAddProvider.notifier).setItems(current, lockToItems: true);

    final total = current.fold<int>(
      0,
      (sum, it) => sum + (it.unitPriceCents * it.quantity),
    );
    _amountCtrl.text = (total / 100).toStringAsFixed(2);

    final cat = ref
        .read(txQuickAddProvider.notifier)
        .autoSelectCategoryForProducts();
    if (cat != null) _categoryCtrl.text = cat.code;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produit ajouté et ligne insérée')),
    );
    setState(() {});
  }

  Future<void> _pickDate() async {
    final current = ref.read(txQuickAddProvider).when;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final newDt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
        current.second,
        current.millisecond,
        current.microsecond,
      );
      ref.read(txQuickAddProvider.notifier).setWhen(newDt);
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cents = parseAmountToCents(_amountCtrl.text);
    final result = await ref
        .read(txQuickAddProvider.notifier)
        .save(amountCents: cents, description: _descCtrl.text);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Erreur inconnue')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(txQuickAddProvider);
    final hasKeyboard = MediaQuery.of(context).viewInsets.bottom > 0.0;

    if (_customerCtrl.text.isEmpty && s.customerId != null) {
      final match = s.customers.where((c) => c.id == s.customerId).toList();
      if (match.isNotEmpty) _customerCtrl.text = match.first.fullName;
    }

    String title;
    switch (s.kind) {
      case TxKind.debit:
        title = 'Ajouter une dépense';
        break;
      case TxKind.credit:
        title = 'Ajouter un revenu';
        break;
      case TxKind.debt:
        title = 'Ajouter une dette';
        break;
      case TxKind.remboursement:
        title = 'Ajouter un remboursement';
        break;
      case TxKind.pret:
        title = 'Ajouter un prêt';
        break;
    }

    String primaryLabel;
    switch (s.kind) {
      case TxKind.debit:
        primaryLabel = 'Ajouter dépense';
        break;
      case TxKind.credit:
        primaryLabel = 'Ajouter revenu';
        break;
      case TxKind.debt:
        primaryLabel = 'Ajouter à la dette';
        break;
      case TxKind.remboursement:
        primaryLabel = 'Ajouter remboursement';
        break;
      case TxKind.pret:
        primaryLabel = 'Ajouter prêt';
        break;
    }

    final showCategory =
        s.kind == TxKind.debit ||
        s.kind == TxKind.credit ||
        s.kind == TxKind.debt;
    final categoryType = s.kind == TxKind.debit
        ? 'DEBIT'
        : (s.kind == TxKind.credit || s.kind == TxKind.debt ? 'CREDIT' : null);
    final showItems =
        s.kind == TxKind.debit ||
        s.kind == TxKind.credit ||
        s.kind == TxKind.debt;

    String? companyLabel() {
      final sel = s.companies.where((co) => co.id == s.companyId).toList();
      return sel.isEmpty ? null : sel.first.name;
    }

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const SubmitFormIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const SubmitFormIntent(),
      },
      child: Actions(
        actions: {
          SubmitFormIntent: CallbackAction<SubmitFormIntent>(
            onInvoke: (_) {
              _save();
              return null;
            },
          ),
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text(title),
            leading: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            actions: [
              IconButton(
                tooltip: primaryLabel,
                icon: const Icon(Icons.check),
                onPressed: _save,
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, hasKeyboard ? 8 : 88),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text(switch (s.kind) {
                        TxKind.debit => 'Type : Dépense',
                        TxKind.credit => 'Type : Revenu',
                        TxKind.debt => 'Type : Dette',
                        TxKind.remboursement => 'Type : Remboursement',
                        TxKind.pret => 'Type : Prêt',
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AmountFieldQuickPad(
                    controller: _amountCtrl,
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
                    lockToItems:
                        showItems && s.items.isNotEmpty && s.lockAmountToItems,
                    onToggleLock: (!showItems || s.items.isEmpty)
                        ? null
                        : (v) {
                            ref
                                .read(txQuickAddProvider.notifier)
                                .setItems(s.items, lockToItems: v);
                            if (v) {
                              final total = s.items.fold<int>(
                                0,
                                (sum, it) =>
                                    sum + (it.unitPriceCents * it.quantity),
                              );
                              _amountCtrl.text = (total / 100).toStringAsFixed(
                                2,
                              );
                              setState(() {});
                            }
                          },
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  if (showCategory)
                    CategoryAutocomplete(
                      controller: _categoryCtrl,
                      initialSelected: s.selectedCategory,
                      optionsBuilder: (q) => ref
                          .read(txQuickAddProvider.notifier)
                          .filterCategories(q),
                      onSelected: (c) {
                        ref
                            .read(txQuickAddProvider.notifier)
                            .setSelectedCategory(c);
                        setState(() {});
                        FocusScope.of(context).nextFocus();
                      },
                      onClear: () {
                        ref
                            .read(txQuickAddProvider.notifier)
                            .setSelectedCategory(null);
                        _categoryCtrl.clear();
                        setState(() {});
                      },
                      labelText: 'Catégorie',
                      emptyHint: categoryType == 'DEBIT'
                          ? 'Aucune catégorie Débit'
                          : 'Aucune catégorie Crédit',
                      typeEntry: categoryType ?? 'CREDIT',
                    ),
                  const SizedBox(height: 12),
                  Card(
                    clipBehavior: Clip.antiAlias,
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
                            value: s.companyId,
                            isDense: true,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('— Aucune société —'),
                              ),
                              ...s.companies.map(
                                (co) => DropdownMenuItem<String?>(
                                  value: co.id,
                                  child: Text(co.name),
                                ),
                              ),
                            ],
                            onChanged: (v) async {
                              ref
                                  .read(txQuickAddProvider.notifier)
                                  .setCompany(v);
                              setState(() {});
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Société',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomerAutocomplete(
                            controller: _customerCtrl,
                            initialSelected: s.customers
                                .where((c) => c.id == s.customerId)
                                .toList()
                                .let((lst) => lst.isEmpty ? null : lst.first),
                            companyLabel: companyLabel(),
                            onCreate: _quickCreateCustomer,
                            optionsBuilder: (query) {
                              final q = query.toLowerCase().trim();
                              Iterable<Customer> base = s.customers;
                              if ((s.companyId ?? '').isNotEmpty) {
                                base = base.where(
                                  (c) => c.companyId == s.companyId,
                                );
                              }
                              if (q.isEmpty) return base.toList();
                              return base.where((c) {
                                final code = (c.code ?? '').toLowerCase();
                                final full = c.fullName.toLowerCase();
                                final phone = (c.phone ?? '').toLowerCase();
                                final email = (c.email ?? '').toLowerCase();
                                return full.contains(q) ||
                                    code.contains(q) ||
                                    phone.contains(q) ||
                                    email.contains(q);
                              }).toList();
                            },
                            onSelected: (c) {
                              ref
                                  .read(txQuickAddProvider.notifier)
                                  .setCustomer(c.id);
                              _customerCtrl.text = c.fullName;
                              setState(() {});
                              FocusScope.of(context).nextFocus();
                            },
                            onClear: () {
                              ref
                                  .read(txQuickAddProvider.notifier)
                                  .setCustomer(null);
                              _customerCtrl.clear();
                              setState(() {});
                            },
                            labelText: 'Client',
                            emptyHint: 'Aucun client dans cette société',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (showItems) ...[
                    const SizedBox(height: 12),
                    ItemsSection(
                      items: s.items,
                      totalCents: s.items.fold(
                        0,
                        (sum, it) => sum + (it.unitPriceCents * it.quantity),
                      ),
                      onPick: _openProductPicker,
                      onClear: () {
                        ref.read(txQuickAddProvider.notifier).clearItems();
                        setState(() {});
                      },
                      onTapItem: _openProductPicker,
                      onCreateProduct: _createProductAndAddLine,
                    ),
                  ],
                  const SizedBox(height: 12),
                  DateRow(when: s.when, onPick: _pickDate),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Description (optionnel)',
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                  ),
                ],
              ),
            ),
          ),
          bottomSheet: BottomBar(
            onCancel: () => Navigator.of(context).maybePop(false),
            onSave: _save,
            primaryLabel: primaryLabel,
          ),
        ),
      ),
    );
  }

  Future<Customer?> _quickCreateCustomer() async {
    final created = await showRightDrawer<Customer?>(
      context,
      child: const CustomerCreatePanel(),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (created == null) return null;

    final currentCompanyId = ref.read(txQuickAddProvider).companyId;
    if ((currentCompanyId ?? '').isEmpty &&
        (created.companyId ?? '').isNotEmpty) {
      ref.read(txQuickAddProvider.notifier).setCompany(created.companyId);
    }

    ref.read(txQuickAddProvider.notifier).setCustomer(created.id);
    _customerCtrl.text = created.fullName;

    if (!mounted) return created;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Client créé et sélectionné')));
    FocusScope.of(context).nextFocus();
    return created;
  }
}

class SubmitFormIntent extends Intent {
  const SubmitFormIntent();
}

extension _LetExt<T> on T {
  R let<R>(R Function(T it) fn) => fn(this);
}
