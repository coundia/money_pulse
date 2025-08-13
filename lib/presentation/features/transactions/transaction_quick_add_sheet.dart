import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

// Parties (Société / Client)
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/domain/customer/entities/customer.dart';

// Repos (interfaces pour les requêtes)
import 'package:money_pulse/domain/company/repositories/company_repository.dart';
import 'package:money_pulse/domain/customer/repositories/customer_repository.dart';

// Providers concrets
import '../../app/account_selection.dart';
import '../../app/providers/company_repo_provider.dart';
import '../../app/providers/customer_repo_provider.dart';
import 'providers/transaction_list_providers.dart';

class TransactionQuickAddSheet extends ConsumerStatefulWidget {
  final bool initialIsDebit;
  const TransactionQuickAddSheet({super.key, this.initialIsDebit = true});

  @override
  ConsumerState<TransactionQuickAddSheet> createState() =>
      _TransactionQuickAddSheetState();
}

class _TransactionQuickAddSheetState
    extends ConsumerState<TransactionQuickAddSheet> {
  final formKey = GlobalKey<FormState>();
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  // Autocomplete catégorie
  final TextEditingController _categoryCtrl = TextEditingController();
  String? categoryId;
  Category? _selectedCategory;
  List<Category> _allCategories = const [];

  // Parties
  String? _companyId;
  String? _customerId;
  List<Company> _companies = const [];
  List<Customer> _customers = const [];

  // Type (lecture seule ici)
  bool isDebit = true;

  // Date
  DateTime when = DateTime.now();

  @override
  void initState() {
    super.initState();
    isDebit = widget.initialIsDebit;

    // Charger catégories + sociétés + (clients filtrés par société si sélectionnée)
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
            companyId: (_companyId ?? '').isEmpty ? null : _companyId,
            limit: 300,
            offset: 0,
          ),
        );

        if (!mounted) return;
        setState(() {
          _allCategories = cats;
          _companies = cos;
          _customers = cus;
          _clearCategory(); // pas de présélection -> évite l’ancienne régression
        });
      } catch (_) {
        // soft fail (UI reste utilisable même si listes vides)
      }
    });
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  // ---------- Helpers ----------

  void _safeSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } else {
      showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Information'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d).maybePop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // Convert "1 500,75" / "1500.75" -> cents
  int _toCents(String v) {
    final s = v.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    final d = double.tryParse(s) ?? 0;
    return (d * 100).round();
  }

  String get _amountPreview =>
      Formatters.amountFromCents(_toCents(amountCtrl.text));

  // Filtre catégories par type + recherche
  List<Category> _filteredCategories({String query = ''}) {
    final wanted = isDebit
        ? 'DEBIT'
        : 'CREDIT'; // évite la régression des constantes
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

  void _clearCategory() {
    _selectedCategory = null;
    categoryId = null;
    _categoryCtrl.clear();
  }

  void _setCategory(Category c) {
    _selectedCategory = c;
    categoryId = c.id;
    _categoryCtrl.text = c.code;
  }

  Future<void> _onSelectCompany(String? id) async {
    setState(() {
      _companyId = id;
      _customerId = null;
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
    } catch (_) {
      // ignore: soft fail
    }
  }

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

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;

    final accountId = ref.read(selectedAccountIdProvider);
    if (accountId == null || accountId.isEmpty) {
      _safeSnack('Sélectionnez d’abord un compte');
      return;
    }

    final cents = _toCents(amountCtrl.text);

    try {
      // companyId / customerId peuvent rester null -> pas bloquant
      await ref
          .read(quickAddTransactionUseCaseProvider)
          .execute(
            accountId: accountId,
            amountCents: cents,
            isDebit: isDebit,
            description: descCtrl.text.trim().isEmpty
                ? null
                : descCtrl.text.trim(),
            categoryId: categoryId, // peut être null -> ok
            dateTransaction: when,
            // ⚠️ Assurez-vous que le UseCase accepte ces 2 paramètres.
            companyId: _companyId,
            customerId: _customerId,
          );

      await ref.read(transactionsProvider.notifier).load();
      await ref.read(balanceProvider.notifier).load();
      ref.invalidate(transactionListItemsProvider);
      ref.invalidate(selectedAccountProvider);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _safeSnack('Échec de l’enregistrement: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    final label = isDebit ? 'Dépense' : 'Revenu';
    final icon = isDebit
        ? Icons.remove_circle_outline
        : Icons.add_circle_outline;
    final color = isDebit
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Scaffold(
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
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type (lecture seule)
                Row(
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: 8),
                    const Text(
                      "Type d'écriture",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Chip(
                      label: Text(label),
                      avatar: Icon(
                        isDebit ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Montant
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Montant',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
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

                // Catégorie (Autocomplete + filtrage par type)
                _CategoryAutocomplete(
                  controller: _categoryCtrl,
                  initialSelected: _selectedCategory,
                  optionsBuilder: (text) => _filteredCategories(query: text),
                  onSelected: (c) => setState(() => _setCategory(c)),
                  onClear: () => setState(() => _clearCategory()),
                  labelText: 'Catégorie',
                  emptyHint: isDebit
                      ? 'Aucune catégorie Débit'
                      : 'Aucune catégorie Crédit',
                ),

                const SizedBox(height: 12),

                // Tiers (Société & Client)
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

                        // IMPORTANT: typage <String?> pour accepter null
                        DropdownButtonFormField<String?>(
                          value: _companyId,
                          isDense: true,
                          items: [
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
                          onChanged: (v) => _onSelectCompany(v),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Société',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),

                        DropdownButtonFormField<String?>(
                          value: _customerId,
                          isDense: true,
                          items: [
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
                          onChanged: (v) => setState(() => _customerId = v),
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

                // Date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(Formatters.dateFull(when)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                ),

                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Description (optionnel)',
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Autocomplete pour les catégories, avec UI matérielle.
/// - `optionsBuilder(query)` retourne la liste filtrée (par type + recherche).
class _CategoryAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final Category? initialSelected;
  final List<Category> Function(String query) optionsBuilder;
  final void Function(Category) onSelected;
  final VoidCallback onClear; // callback clear
  final String labelText;
  final String emptyHint;

  const _CategoryAutocomplete({
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
            // Lier notre controller initial une fois
            if (controller.text.isNotEmpty &&
                textEditingController.text.isEmpty) {
              textEditingController.text = controller.text;
            }

            // Afficher/masquer l’icône clear selon le texte
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
                              // Efface le champ ET la sélection parent
                              textEditingController.clear();
                              controller.clear();
                              onClear();
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) {
                    // garder les deux en phase
                    controller.value = textEditingController.value;
                  },
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
