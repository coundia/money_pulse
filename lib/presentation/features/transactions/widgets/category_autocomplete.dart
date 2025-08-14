// lib/presentation/features/transactions/widgets/category_autocomplete.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:money_pulse/domain/categories/entities/category.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/app/providers.dart'
    show categoryRepoProvider;

import '../../categories/widgets/category_form_panel.dart';

class CategoryAutocomplete extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final Category? initialSelected;

  /// Builds options (you already filter by type in the caller)
  final List<Category> Function(String query) optionsBuilder;

  final void Function(Category) onSelected;
  final VoidCallback onClear;
  final String labelText;
  final String emptyHint;

  /// Tell the widget which type we’re in so new category creation is locked to it.
  final String typeEntry; // 'DEBIT' or 'CREDIT'

  const CategoryAutocomplete({
    super.key,
    required this.controller,
    required this.initialSelected,
    required this.optionsBuilder,
    required this.onSelected,
    required this.onClear,
    required this.labelText,
    required this.emptyHint,
    required this.typeEntry,
  });

  @override
  ConsumerState<CategoryAutocomplete> createState() =>
      _CategoryAutocompleteState();
}

class _CategoryAutocompleteState extends ConsumerState<CategoryAutocomplete> {
  Future<void> _createCategory(BuildContext context) async {
    final form = await showRightDrawer<CategoryFormResult>(
      context,
      child: CategoryFormPanel(forcedTypeEntry: widget.typeEntry),
      widthFraction: 0.86,
      heightFraction: 0.90,
    );
    if (form == null) return;

    // Persist
    final repo = ref.read(categoryRepoProvider);
    final now = DateTime.now();
    final cat = Category(
      id: const Uuid().v4(),
      code: form.code,
      description: form.description,
      typeEntry: form.typeEntry,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      remoteId: null,
      syncAt: null,
      version: 0,
      isDirty: true,
    );
    await repo.create(cat);

    // Update UI selection
    widget.controller.text = cat.code;
    widget.onSelected(cat);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Catégorie créée')));
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Category>(
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text;
        return widget.optionsBuilder(q);
      },
      displayStringForOption: (c) =>
          c.code +
          ((c.description?.isNotEmpty ?? false) ? ' — ${c.description}' : ''),
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            if (widget.controller.text.isNotEmpty &&
                textEditingController.text.isEmpty) {
              textEditingController.text = widget.controller.text;
            }
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: textEditingController,
              builder: (context, value, _) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.labelText,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Créer',
                          icon: const Icon(Icons.add),
                          onPressed: () => _createCategory(context),
                        ),
                        if (value.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Effacer',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              textEditingController.clear();
                              widget.controller.clear();
                              widget.onClear();
                            },
                          ),
                      ],
                    ),
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
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 520),
              child: opts.isEmpty
                  ? ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: const Text('Créer une catégorie'),
                          subtitle: Text(
                            widget.typeEntry == 'DEBIT'
                                ? 'Type: Débit (dépense)'
                                : 'Type: Crédit (revenu)',
                          ),
                          onTap: () => _createCategory(context),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            widget.emptyHint,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: opts.length + 1, // +1 for "Créer" shortcut
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 0.5),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return ListTile(
                            leading: const Icon(Icons.add),
                            title: const Text('Créer une catégorie'),
                            subtitle: Text(
                              widget.typeEntry == 'DEBIT'
                                  ? 'Type: Débit (dépense)'
                                  : 'Type: Crédit (revenu)',
                            ),
                            onTap: () => _createCategory(context),
                          );
                        }
                        final c = opts[i - 1];
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
        widget.controller.text = c.code;
        widget.onSelected(c);
      },
    );
  }
}
