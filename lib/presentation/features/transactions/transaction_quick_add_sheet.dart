import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

import '../../app/account_selection.dart';
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
  final TextEditingController _categoryCtrl = TextEditingController();

  bool isDebit = true;
  String? categoryId;
  Category? _selectedCategory;

  DateTime when = DateTime.now();
  List<Category> _allCategories = const [];

  @override
  void initState() {
    super.initState();
    isDebit = widget.initialIsDebit;
    // Charger les catégories
    Future.microtask(() async {
      final repo = ref.read(categoryRepoProvider);
      final cats = await repo.findAllActive();
      if (!mounted) return;
      setState(() {
        _allCategories = cats;
        // Pas de présélection automatique : on laisse vide
        _clearCategory();
      });
    });
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  // --- Helpers UI ---

  void _safeSnack(String message) {
    if (!mounted) return;

    final scaffoldState = context.findAncestorStateOfType<ScaffoldState>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (scaffoldState != null && messenger != null && messenger.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(message)));
      });
      return;
    }

    // ✅ Utiliser un nom explicite pour le contexte du builder
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Information'),
        content: Text(message),
        actions: [
          TextButton(
            // ✅ Utiliser dialogContext ici, pas `_`
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).maybePop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Convert "123,45" / "123.45" -> cents
  int _toCents(String v) {
    final s = v.replaceAll(',', '.').replaceAll(' ', '');
    final d = double.tryParse(s) ?? 0;
    return (d * 100).round();
  }

  // Filtrer par type en fonction de isDebit
  List<Category> _filteredCategories({String query = ''}) {
    final wanted = isDebit ? Category.debit : Category.credit;
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

  // (Conservé si un jour tu réactives un switch de type)
  void _onTypeChanged(bool newIsDebit) {
    if (isDebit == newIsDebit) return;
    setState(() {
      isDebit = newIsDebit;
      _clearCategory();
    });
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

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const SizedBox(width: 8),
                  Text(
                    'Ajouter une transaction',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),

              // Type: dépense / revenu (lecture seule)
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
              ),

              const SizedBox(height: 12),

              // Catégorie (Autocomplete + recherche + filtrage par type)
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

              // Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(Formatters.dateFull(when)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: when,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => when = picked);
                },
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

              const SizedBox(height: 16),

              // Enregistrer
              FilledButton.icon(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final accountId = ref.read(selectedAccountIdProvider);
                  if (accountId == null || accountId.isEmpty) {
                    if (!mounted) return;
                    _safeSnack('Sélectionnez d’abord un compte');
                    return;
                  }

                  if (categoryId == null || categoryId!.isEmpty) {
                    if (!mounted) return;
                    // _safeSnack('Sélectionnez une catégorie');
                    //return;
                  }

                  final cents = _toCents(amountCtrl.text);
                  await ref
                      .read(quickAddTransactionUseCaseProvider)
                      .execute(
                        accountId: accountId,
                        amountCents: cents,
                        isDebit: isDebit,
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        categoryId: categoryId,
                        dateTransaction: when,
                      );

                  await ref.read(transactionsProvider.notifier).load();
                  await ref.read(balanceProvider.notifier).load();
                  ref.invalidate(transactionListItemsProvider);
                  ref.invalidate(selectedAccountProvider);

                  if (mounted) Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.check),
                label: const Text('Enregistrer'),
              ),
            ],
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
                            c.typeEntry == Category.debit ? 'Débit' : 'Crédit',
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
