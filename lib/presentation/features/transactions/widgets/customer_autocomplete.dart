import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/features/customers/customer_form_panel.dart';

class CustomerAutocomplete extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final Customer? initialSelected;

  /// Build local options (typically filter your `_customers` by [query]).
  final List<Customer> Function(String query) optionsBuilder;

  /// Called when a customer is picked (propagate `customer.id` to parent).
  final void Function(Customer) onSelected;

  /// Clear current selection.
  final VoidCallback onClear;

  final String labelText;
  final String emptyHint;

  /// Optional: show context to the user when creating a customer.
  final String? companyLabel;

  /// Optional: if provided, used to create a customer and return it.
  /// Otherwise the widget will open [CustomerFormPanel] itself.
  final Future<Customer?> Function()? onCreate;

  const CustomerAutocomplete({
    super.key,
    required this.controller,
    required this.initialSelected,
    required this.optionsBuilder,
    required this.onSelected,
    required this.onClear,
    required this.labelText,
    required this.emptyHint,
    this.companyLabel,
    this.onCreate,
  });

  @override
  ConsumerState<CustomerAutocomplete> createState() =>
      _CustomerAutocompleteState();
}

class _CustomerAutocompleteState extends ConsumerState<CustomerAutocomplete> {
  Future<void> _createCustomer(BuildContext context) async {
    Customer? created;

    if (widget.onCreate != null) {
      created = await widget.onCreate!.call();
    } else {
      created = await showRightDrawer<Customer?>(
        context,
        child: const CustomerFormPanel(),
        widthFraction: 0.86,
        heightFraction: 0.96,
      );
    }

    if (created == null) return;

    // Show value in field and notify parent
    widget.controller.text = created.fullName;
    widget.onSelected(created);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Client créé et sélectionné')));
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Customer>(
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text;
        return widget.optionsBuilder(q);
      },
      displayStringForOption: (c) => c.fullName,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            // hydrate with controller’s initial value
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
                          tooltip: 'Créer un client',
                          icon: const Icon(Icons.person_add_alt),
                          onPressed: () => _createCustomer(context),
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
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: (opts.isEmpty ? 1 : opts.length + 1),
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, thickness: 0.5),
                itemBuilder: (_, i) {
                  // First row: "Create" shortcut
                  if (i == 0) {
                    return ListTile(
                      leading: const Icon(Icons.person_add_alt),
                      title: const Text('Créer un client'),
                      subtitle: (widget.companyLabel?.isNotEmpty ?? false)
                          ? Text('Société: ${widget.companyLabel!}')
                          : null,
                      onTap: () => _createCustomer(context),
                    );
                  }
                  final c = opts[i - 1];
                  return ListTile(
                    dense: true,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(c.fullName),
                    subtitle: _subtitleFor(c),
                    onTap: () => onSelectedCb(c),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (c) {
        widget.controller.text = c.fullName;
        widget.onSelected(c);
      },
    );
  }

  Widget? _subtitleFor(Customer c) {
    final parts = <String>[
      if ((c.code ?? '').isNotEmpty) '#${c.code}',
      if ((c.phone ?? '').isNotEmpty) c.phone!,
      if ((c.email ?? '').isNotEmpty) c.email!,
    ];
    if (parts.isEmpty) return null;
    return Text(parts.join(' • '));
  }
}
