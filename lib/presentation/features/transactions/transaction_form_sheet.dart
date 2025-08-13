// TransactionFormSheet: edit a transaction with category, tiers and products picker; loads saved items on edit; responsive, Enter-to-save, no overflow.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../products/product_picker_panel.dart';
import '../../widgets/right_drawer.dart';

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

  bool isDebit = true;
  String? categoryId;
  DateTime when = DateTime.now();

  String? companyId;
  String? customerId;
  List<Company> companies = const [];
  List<Customer> customers = const [];
  List<Category> categories = const [];

  final List<_TxItem> _items = [];

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    isDebit = e.typeEntry == 'DEBIT';
    amountCtrl.text = (e.amount / 100).toStringAsFixed(2);
    descCtrl.text = e.description ?? '';
    categoryId = e.categoryId;
    when = e.dateTransaction;
    companyId = e.companyId;
    customerId = e.customerId;

    Future.microtask(() async {
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
        if (!mounted) return;
        setState(() {
          categories = cats;
          companies = cos;
          customers = cus;
        });
      } catch (_) {}
      await _loadExistingItems();
    });
  }

  Future<void> _loadExistingItems() async {
    try {
      final saved = await ref.read(
        transactionItemsProvider(widget.entry.id).future,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(
            saved
                .where(
                  (it) => it.productId != null,
                ) // on ne charge que les lignes liées à des produits
                .map(
                  (it) => _TxItem(
                    productId: it.productId!,
                    label: (it.label ?? '').isEmpty ? 'Produit' : it.label!,
                    unitPriceCents: it.unitPrice,
                    quantity: it.quantity,
                  ),
                ),
          );
      });
      // On ne force pas le montant à partir des articles à l'ouverture,
      // mais si l’utilisateur rouvre le sélecteur produits, le montant se resynchronise automatiquement.
    } catch (_) {}
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  int _toCents(String v) {
    final s = v.replaceAll(',', '.').replaceAll(' ', '');
    final d = double.tryParse(s) ?? 0;
    return (d * 100).round();
  }

  String get _amountPreview =>
      Formatters.amountFromCents(_toCents(amountCtrl.text));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
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
      customers = const [];
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
      setState(() => customers = list);
    } catch (_) {}
  }

  int get _itemsTotalCents =>
      _items.fold(0, (sum, it) => sum + (it.unitPriceCents * it.quantity));

  void _syncAmountFromItems() {
    final total = _itemsTotalCents;
    amountCtrl.text = (total / 100).toStringAsFixed(2);
    setState(() {});
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
      });
      _syncAmountFromItems();
    }
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final cents = _toCents(amountCtrl.text);
    if (cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le montant doit être supérieur à 0')),
      );
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
      version: widget.entry.version + 1,
    );
    await ref.read(transactionRepoProvider).update(updated);
    if (mounted) Navigator.of(context).pop(true);
  }

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
            title: const Text('Modifier la transaction'),
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
          ),
          body: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
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
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,\s]')),
                  ],
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Montant',
                    helperText: 'Exemple : 1500,00',
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
                const SizedBox(height: 12),

                // Catégorie — corrige le "overflow by pixels" via isExpanded + selectedItemBuilder + ellipsis
                Builder(
                  builder: (context) {
                    final filtered = categories
                        .where((c) => c.typeEntry == widget.entry.typeEntry)
                        .toList();
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
                          // width-safe
                        ),
                      ),
                    ];
                    return DropdownButtonFormField<String?>(
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
                    );
                  },
                ),

                const SizedBox(height: 12),
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
                          selectedItemBuilder: (ctx) => [
                            const Text(
                              '— Aucune société —',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            ...companies.map(
                              (co) => Text(
                                '${co.name} (${co.code})',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                          onChanged: (v) => _onSelectCompany(v),
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
                          isExpanded: true,
                          items: <DropdownMenuItem<String?>>[
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
                          selectedItemBuilder: (ctx) => [
                            const Text(
                              '— Aucun client —',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            ...customers.map(
                              (cu) => Text(
                                cu.fullName,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => customerId = v),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Client',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openProductPicker,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: Text(
                          _items.isEmpty
                              ? 'Ajouter des produits'
                              : 'Modifier les produits',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_items.isNotEmpty)
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
                              setState(() => _items.clear());
                              _syncAmountFromItems();
                            },
                            icon: const Icon(Icons.delete_sweep),
                          ),
                        ],
                      ),
                  ],
                ),
                if (_items.isNotEmpty) const SizedBox(height: 8),
                if (_items.isNotEmpty)
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

                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Description',
                  ),
                  minLines: 1,
                  maxLines: 3,
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
                const SizedBox(height: 16),
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
