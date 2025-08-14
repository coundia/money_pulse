import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/presentation/app/providers.dart'
    hide checkoutCartUseCaseProvider;
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/domain/company/repositories/company_repository.dart';
import 'package:money_pulse/domain/customer/repositories/customer_repository.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/products/entities/product.dart';
import '../../app/account_selection.dart';
import '../../app/providers/company_repo_provider.dart';
import '../../app/providers/customer_repo_provider.dart';
import '../../widgets/right_drawer.dart';
import '../products/product_picker_panel.dart';
import '../products/product_repo_provider.dart';
import '../products/widgets/product_form_panel.dart';
import 'providers/transaction_list_providers.dart';
import '../../app/providers/checkout_cart_usecase_provider.dart';

// local pieces
import 'intents/submit_form_intent.dart' hide SubmitFormIntent;
import 'models/tx_item.dart';
import 'widgets/amount_field.dart';
import 'widgets/bottom_bar.dart';
import 'widgets/category_autocomplete.dart';
import 'widgets/date_row.dart';
import 'widgets/items_section.dart';
import 'widgets/party_section.dart';
import 'widgets/type_header.dart';

class TransactionQuickAddSheet extends ConsumerStatefulWidget {
  final bool initialIsDebit; // fixed at construction time
  const TransactionQuickAddSheet({super.key, this.initialIsDebit = true});

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

  late final bool _isDebit = widget.initialIsDebit; // FIXED — no toggle
  DateTime _when = DateTime.now();

  Category? _selectedCategory;
  List<Category> _allCategories = const [];

  String? _companyId;
  String? _customerId;
  List<Company> _companies = const [];
  List<Customer> _customers = const [];

  final List<TxItem> _items = [];
  bool _lockAmountToItems = true;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final catRepo = ref.read(categoryRepoProvider);
      final coRepo = ref.read(companyRepoProvider);
      final cuRepo = ref.read(customerRepoProvider);

      final cats = await catRepo.findAllActive();
      final cos = await coRepo.findAll(
        const CompanyQuery(limit: 300, offset: 0),
      );

      Company? def;
      try {
        def = cos.firstWhere((e) => e.isDefault == true);
      } catch (_) {
        def = cos.isNotEmpty ? cos.first : null;
      }

      String? selectedCompanyId = def?.id;
      List<Customer> cus = const [];
      if (selectedCompanyId != null) {
        cus = await cuRepo.findAll(
          CustomerQuery(companyId: selectedCompanyId, limit: 300, offset: 0),
        );
      }

      if (!mounted) return;
      setState(() {
        _allCategories = cats;
        _companies = cos;
        _companyId = selectedCompanyId;
        _customers = cus;
        _customerId = null;
        _clearCategoryInternal();
      });
    } catch (_) {}
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int _parseAmountToCents(String v) {
    final s = v.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    final d = double.tryParse(s) ?? 0;
    return (d * 100).round();
  }

  String get _amountPreview =>
      Formatters.amountFromCents(_parseAmountToCents(_amountCtrl.text));

  List<Category> _filteredCategories(String query) {
    final wanted = _isDebit ? 'DEBIT' : 'CREDIT';
    final base = _allCategories.where((c) => c.typeEntry == wanted);
    if (query.trim().isEmpty) return base.toList();
    final q = query.toLowerCase().trim();
    return base
        .where(
          (c) =>
              c.code.toLowerCase().contains(q) ||
              (c.description ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  void _clearCategoryInternal() {
    _selectedCategory = null;
    _categoryCtrl.clear();
  }

  void _setCategoryInternal(Category c) {
    _selectedCategory = c;
    _categoryCtrl.text = c.code;
  }

  Future<void> _onSelectCompany(String? id) async {
    setState(() {
      _companyId = id;
      _customerId = null;
      _customers = const [];
    });
    try {
      if (id == null || id.isEmpty) return;
      final cuRepo = ref.read(customerRepoProvider);
      final list = await cuRepo.findAll(
        CustomerQuery(companyId: id, limit: 300, offset: 0),
      );
      if (!mounted) return;
      setState(() => _customers = list);
    } catch (_) {}
  }

  Future<void> _ensureDefaultCompanyIfMissing() async {
    if (_companyId != null && _companyId!.isNotEmpty) return;
    try {
      final coRepo = ref.read(companyRepoProvider);
      final cos = await coRepo.findAll(
        const CompanyQuery(limit: 300, offset: 0),
      );
      Company? def;
      try {
        def = cos.firstWhere((e) => e.isDefault == true);
      } catch (_) {
        def = cos.isNotEmpty ? cos.first : null;
      }
      if (!mounted) return;
      setState(() => _companyId = def?.id);
    } catch (_) {}
  }

  int get _itemsTotalCents =>
      _items.fold(0, (sum, it) => sum + (it.unitPriceCents * it.quantity));

  void _syncAmountFromItems() {
    if (_items.isEmpty) return;
    final total = _itemsTotalCents;
    _amountCtrl.text = (total / 100).toStringAsFixed(2);
    setState(() {});
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
      setState(() {
        _items
          ..clear()
          ..addAll(parsed);
        _lockAmountToItems = true;
      });
      _syncAmountFromItems();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _when = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _when.hour,
          _when.minute,
          _when.second,
          _when.millisecond,
          _when.microsecond,
        );
      });
    }
  }

  Future<void> _createProductAndAddLine() async {
    // Load categories for the form
    final categories = await ref.read(categoryRepoProvider).findAllActive();
    if (!mounted) return;

    final formRes = await showRightDrawer<ProductFormResult?>(
      context,
      child: ProductFormPanel(existing: null, categories: categories),
      widthFraction: 0.92,
      heightFraction: 0.96,
    );
    if (formRes == null) return;

    // Persist product
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

    // Add a line to the current items with qty = 1
    setState(() {
      _items.add(
        TxItem(
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

    _snack('Produit ajouté et ligne insérée');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _ensureDefaultCompanyIfMissing();

    final accountId = ref.read(selectedAccountIdProvider);
    if (accountId == null || accountId.isEmpty) {
      _snack('Sélectionnez d’abord un compte');
      return;
    }

    final cents = _parseAmountToCents(_amountCtrl.text);
    final lines = _items.isNotEmpty
        ? _items
              .map<Map<String, Object?>>(
                (it) => {
                  'productId': it.productId,
                  'label': it.label,
                  'quantity': it.quantity,
                  'unitPrice': it.unitPriceCents,
                },
              )
              .toList()
        : <Map<String, Object?>>[
            {
              'productId': null,
              'label': (_descCtrl.text.trim().isEmpty
                  ? (_isDebit ? 'Dépense' : 'Revenu')
                  : _descCtrl.text.trim()),
              'quantity': 1,
              'unitPrice': cents,
            },
          ];

    try {
      await ref
          .read(checkoutCartUseCaseProvider)
          .execute(
            typeEntry: _isDebit ? 'DEBIT' : 'CREDIT',
            accountId: accountId,
            categoryId: _selectedCategory?.id,
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            companyId: _companyId,
            customerId: _customerId,
            when: _when,
            lines: lines,
          );

      await ref.read(transactionsProvider.notifier).load();
      await ref.read(balanceProvider.notifier).load();
      ref.invalidate(transactionListItemsProvider);
      ref.invalidate(selectedAccountProvider);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Échec de l’enregistrement: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final primaryLabel = _isDebit ? 'Ajouter dépense' : 'Ajouter revenu';
    final title = _isDebit ? 'Ajouter une dépense' : 'Ajouter un revenu';

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const SubmitFormIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const SubmitFormIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SubmitFormIntent: CallbackAction<SubmitFormIntent>(
            onInvoke: (_) {
              _save();
              return null;
            },
          ),
        },
        child: Scaffold(
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
          body: Padding(
            padding: EdgeInsets.only(bottom: insets),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypeHeader(isDebit: _isDebit), // static header (no toggle)
                    const SizedBox(height: 12),
                    AmountField(
                      controller: _amountCtrl,
                      lockToItems: _items.isNotEmpty && _lockAmountToItems,
                      onToggleLock: _items.isEmpty
                          ? null
                          : (v) {
                              setState(() {
                                _lockAmountToItems = v;
                                if (v) _syncAmountFromItems();
                              });
                            },
                      onChanged: () => setState(() {}),
                      preview: _amountPreview,
                    ),
                    const SizedBox(height: 12),
                    CategoryAutocomplete(
                      controller: _categoryCtrl,
                      initialSelected: _selectedCategory,
                      optionsBuilder: _filteredCategories,
                      onSelected: (c) =>
                          setState(() => _setCategoryInternal(c)),
                      onClear: () => setState(() => _clearCategoryInternal()),
                      labelText: 'Catégorie',
                      emptyHint: _isDebit
                          ? 'Aucune catégorie Débit'
                          : 'Aucune catégorie Crédit',
                    ),
                    const SizedBox(height: 12),
                    PartySection(
                      companies: _companies,
                      customers: _customers,
                      companyId: _companyId,
                      customerId: _customerId,
                      itemsCount: _items.length,
                      isDebit: _isDebit,
                      onCompanyChanged: _onSelectCompany,
                      onCustomerChanged: (v) => setState(() => _customerId = v),
                    ),
                    const SizedBox(height: 12),
                    ItemsSection(
                      items: _items,
                      totalCents: _itemsTotalCents,
                      onPick: _openProductPicker,
                      onClear: () {
                        setState(() {
                          _items.clear();
                          _lockAmountToItems = false;
                        });
                      },
                      onTapItem: _openProductPicker,
                      onCreateProduct: _createProductAndAddLine,
                    ),
                    const SizedBox(height: 12),
                    DateRow(when: _when, onPick: _pickDate),
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
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
          bottomSheet: BottomBar(
            onCancel: () => Navigator.of(context).maybePop(false),
            onSave: _save,
            primaryLabel: primaryLabel, // NEW label
          ),
        ),
      ),
    );
  }
}
