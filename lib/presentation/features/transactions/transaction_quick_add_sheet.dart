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

import '../../app/account_selection.dart';
import '../../app/providers/company_repo_provider.dart';
import '../../app/providers/customer_repo_provider.dart';
import '../../widgets/right_drawer.dart';
import '../products/product_picker_panel.dart';
import 'providers/transaction_list_providers.dart';
import '../../app/providers/checkout_cart_usecase_provider.dart';

/// ===============================
/// TransactionQuickAddSheet (SRP)
/// ===============================
class TransactionQuickAddSheet extends ConsumerStatefulWidget {
  final bool initialIsDebit;
  const TransactionQuickAddSheet({super.key, this.initialIsDebit = true});

  @override
  ConsumerState<TransactionQuickAddSheet> createState() =>
      _TransactionQuickAddSheetState();
}

class _TransactionQuickAddSheetState
    extends ConsumerState<TransactionQuickAddSheet> {
  // --- Controllers & State ---
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();

  bool _isDebit = true;
  DateTime _when = DateTime.now();

  // Category
  Category? _selectedCategory;
  List<Category> _allCategories = const [];

  // Party (Company + Customer)
  String? _companyId;
  String? _customerId;
  List<Company> _companies = const [];
  List<Customer> _customers = const [];

  // Items (from ProductPicker)
  final List<_TxItem> _items = [];
  bool _lockAmountToItems = true; // when products exist

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _isDebit = widget.initialIsDebit;
    _loadInitialData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  // --- Data loading ---
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
    } catch (_) {
      // Silent, keep UI usable
    }
  }

  // --- Helpers ---
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
    } catch (_) {
      // ignore
    }
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
    } catch (_) {
      // ignore
    }
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
        _lockAmountToItems = true; // default lock when items exist
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _ensureDefaultCompanyIfMissing();

    final accountId = ref.read(selectedAccountIdProvider);
    if (accountId == null || accountId.isEmpty) {
      _snack('Sélectionnez d’abord un compte');
      return;
    }

    // Prepare lines (items or single line from amount)
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

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const _SubmitFormIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter):
            const _SubmitFormIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SubmitFormIntent: CallbackAction<_SubmitFormIntent>(
            onInvoke: (_) {
              _save();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Ajouter une transaction'),
            leading: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            actions: [
              IconButton(
                tooltip: 'Enregistrer',
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
                    _TypeToggle(
                      isDebit: _isDebit,
                      onChanged: (v) {
                        setState(() {
                          _isDebit = v;
                          // reset category when flipping type to avoid mismatch
                          _clearCategoryInternal();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _AmountField(
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
                    _CategoryAutocomplete(
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
                    _PartySection(
                      companies: _companies,
                      customers: _customers,
                      companyId: _companyId,
                      customerId: _customerId,
                      itemsCount: _items.length,
                      isDebit: _isDebit,
                      onCompanyChanged: _onSelectCompany,
                      onCustomerChanged: (v) => setState(() => _customerId = v),
                      // Info banner text informs stock flow direction
                    ),
                    const SizedBox(height: 12),
                    _ItemsSection(
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
                    ),
                    const SizedBox(height: 12),
                    _DateRow(when: _when, onPick: _pickDate),
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
                    const SizedBox(height: 80), // keep space above bottom bar
                  ],
                ),
              ),
            ),
          ),
          bottomSheet: _BottomBar(
            onCancel: () => Navigator.of(context).maybePop(false),
            onSave: _save,
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// Smaller, focused UI widgets (SRP)
/// ===============================

class _TypeToggle extends StatelessWidget {
  final bool isDebit;
  final ValueChanged<bool> onChanged;
  const _TypeToggle({required this.isDebit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = isDebit ? cs.error : cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(isDebit ? Icons.south : Icons.north, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.south),
                  label: Text('Dépense'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.north),
                  label: Text('Revenu'),
                ),
              ],
              selected: {isDebit},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text(isDebit ? 'Dépense' : 'Revenu'),
            avatar: Icon(
              isDebit ? Icons.arrow_downward : Icons.arrow_upward,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final bool lockToItems;
  final ValueChanged<bool>? onToggleLock;
  final VoidCallback onChanged;
  final String preview;

  const _AmountField({
    required this.controller,
    required this.lockToItems,
    required this.onChanged,
    required this.preview,
    this.onToggleLock,
  });

  @override
  Widget build(BuildContext context) {
    final readOnly = lockToItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]')),
          ],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Montant',
            suffixIcon: onToggleLock == null
                ? null
                : Tooltip(
                    message: lockToItems
                        ? "Montant verrouillé sur le total des articles"
                        : "Saisir manuellement le montant",
                    child: Switch(value: lockToItems, onChanged: onToggleLock),
                  ),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          autofocus: true,
          onChanged: (_) => onChanged(),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Aperçu: $preview',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _PartySection extends StatelessWidget {
  final List<Company> companies;
  final List<Customer> customers;
  final String? companyId;
  final String? customerId;
  final int itemsCount;
  final bool isDebit;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onCustomerChanged;

  const _PartySection({
    required this.companies,
    required this.customers,
    required this.companyId,
    required this.customerId,
    required this.itemsCount,
    required this.isDebit,
    required this.onCompanyChanged,
    required this.onCustomerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final flowText = itemsCount == 0
        ? null
        : (isDebit
              ? 'Le stock sera augmenté pour $itemsCount produit(s) dans la société sélectionnée.'
              : 'Le stock sera diminué pour $itemsCount produit(s) dans la société sélectionnée.');

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tiers', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: companyId,
              isDense: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Aucune société —'),
                ),
                ...companies.map(
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
              onChanged: onCompanyChanged,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Société',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: customerId,
              isDense: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Aucun client —'),
                ),
                ...customers.map(
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
              onChanged: onCustomerChanged,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Client',
                isDense: true,
              ),
            ),
            if (flowText != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(flowText, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemsSection extends StatelessWidget {
  final List<_TxItem> items;
  final int totalCents;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final VoidCallback onTapItem;

  const _ItemsSection({
    required this.items,
    required this.totalCents,
    required this.onPick,
    required this.onClear,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  items.isEmpty
                      ? 'Ajouter des produits'
                      : 'Modifier les produits',
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (items.isNotEmpty)
              Wrap(
                spacing: 6,
                children: [
                  Chip(label: Text('${items.length} produit(s)')),
                  Chip(
                    label: Text(
                      'Total: ${Formatters.amountFromCents(totalCents)}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Vider',
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_sweep),
                  ),
                ],
              ),
          ],
        ),
        if (items.isNotEmpty) const SizedBox(height: 8),
        if (items.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final it = items[i];
              final lineTotal = it.unitPriceCents * it.quantity;
              return ListTile(
                dense: true,
                leading: const Icon(Icons.shopping_bag),
                title: Text(it.label.isEmpty ? 'Produit' : it.label),
                subtitle: Text(
                  'Qté: ${it.quantity} • PU: ${Formatters.amountFromCents(it.unitPriceCents)}',
                ),
                trailing: Text(Formatters.amountFromCents(lineTotal)),
                onTap: onTapItem,
              );
            },
          ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final DateTime when;
  final VoidCallback onPick;
  const _DateRow({required this.when, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Date'),
      subtitle: Text(Formatters.dateFull(when)),
      trailing: const Icon(Icons.calendar_today),
      onTap: onPick,
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;
  const _BottomBar({required this.onCancel, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 0.6),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.check),
                label: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Model for product lines
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

/// Intent to submit on Enter
class _SubmitFormIntent extends Intent {
  const _SubmitFormIntent();
}

/// Reusable category autocomplete
class _CategoryAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final Category? initialSelected;
  final List<Category> Function(String query) optionsBuilder;
  final void Function(Category) onSelected;
  final VoidCallback onClear;
  final String labelText;
  final String emptyHint;

  const _CategoryAutocomplete({
    super.key,
    required this.controller,
    required this.initialSelected,
    required this.optionsBuilder,
    required this.onSelected,
    required this.onClear,
    required this.labelText,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Category>(
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text;
        return optionsBuilder(q);
      },
      displayStringForOption: (c) =>
          c.code +
          ((c.description?.isNotEmpty ?? false) ? ' — ${c.description}' : ''),
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            if (controller.text.isNotEmpty &&
                textEditingController.text.isEmpty) {
              textEditingController.text = controller.text;
            }
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: textEditingController,
              builder: (context, value, _) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: labelText,
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Effacer',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              textEditingController.clear();
                              controller.clear();
                              onClear();
                            },
                          )
                        : null,
                  ),
                  textInputAction: TextInputAction.next,
                );
              },
            );
          },
      optionsViewBuilder: (context, onSelectedCb, options) {
        final opts = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 480),
              child: opts.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        emptyHint,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: opts.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 0.5),
                      itemBuilder: (_, i) {
                        final c = opts[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            child: Text(
                              (c.code.isNotEmpty ? c.code[0] : '?')
                                  .toUpperCase(),
                            ),
                          ),
                          title: Text(c.code),
                          subtitle: c.description?.isNotEmpty == true
                              ? Text(c.description!)
                              : null,
                          trailing: Text(
                            c.typeEntry == 'DEBIT' ? 'Débit' : 'Crédit',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => onSelectedCb(c),
                        );
                      },
                    ),
            ),
          ),
        );
      },
      onSelected: (c) {
        controller.text = c.code;
        onSelected(c);
      },
    );
  }
}
