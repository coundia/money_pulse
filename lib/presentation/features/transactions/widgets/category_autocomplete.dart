import 'package:flutter/material.dart';
import 'package:money_pulse/domain/categories/entities/category.dart';

class CategoryAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final Category? initialSelected;
  final List<Category> Function(String query) optionsBuilder;
  final void Function(Category) onSelected;
  final VoidCallback onClear;
  final String labelText;
  final String emptyHint;

  const CategoryAutocomplete({
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
