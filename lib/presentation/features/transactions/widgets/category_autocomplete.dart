// Minimal autocomplete for categories with dynamic popup height and focus handoff.

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
  final List<Category> Function(String query) optionsBuilder;
  final void Function(Category) onSelected;
  final VoidCallback onClear;
  final String labelText;
  final String emptyHint;
  final String typeEntry;

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

    widget.controller.text = cat.code;
    widget.onSelected(cat);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Catégorie créée')));
    FocusScope.of(context).nextFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Category>(
      optionsBuilder: (textEditingValue) =>
          widget.optionsBuilder(textEditingValue.text),
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
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                );
              },
            );
          },
      optionsViewBuilder: (context, onSelectedCb, options) {
        final opts = options.toList();
        final size = MediaQuery.of(context).size;
        final maxH = (size.height * 0.40).clamp(200.0, 420.0) as double;
        final maxW = (size.width * 0.96).clamp(280.0, 520.0) as double;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH, maxWidth: maxW),
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
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Aucun résultat',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: opts.length + 1,
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
                          onTap: () {
                            onSelectedCb(c);
                            FocusScope.of(context).nextFocus();
                          },
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
        FocusScope.of(context).nextFocus();
      },
    );
  }
}
