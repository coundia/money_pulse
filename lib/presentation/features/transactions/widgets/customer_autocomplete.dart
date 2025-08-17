// Customer autocomplete with keyboard-safe popup height and focus handoff to next field.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:money_pulse/domain/customer/entities/customer.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/features/customers/customer_form_panel.dart';

class CustomerAutocomplete extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final Customer? initialSelected;
  final List<Customer> Function(String query) optionsBuilder;
  final void Function(Customer) onSelected;
  final VoidCallback onClear;
  final String labelText;
  final String emptyHint;
  final String? companyLabel;
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
    widget.controller.text = created.fullName;
    widget.onSelected(created);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Client créé et sélectionné')));
    FocusScope.of(context).nextFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Customer>(
      optionsBuilder: (textEditingValue) =>
          widget.optionsBuilder(textEditingValue.text),
      displayStringForOption: (c) => c.fullName,
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
                          tooltip: 'Créer un client',
                          icon: const Icon(Icons.person_add_alt),
                          onPressed: () async {
                            FocusScope.of(context).unfocus();
                            await Future<void>.delayed(
                              const Duration(milliseconds: 1),
                            );
                            if (!mounted) return;
                            await _createCustomer(this.context);
                          },
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
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: (opts.isEmpty ? 1 : opts.length + 1),
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, thickness: 0.5),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return ListTile(
                      leading: const Icon(Icons.person_add_alt),
                      title: const Text('Créer un client'),
                      subtitle: (widget.companyLabel?.isNotEmpty ?? false)
                          ? Text('Société: ${widget.companyLabel!}')
                          : null,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 1),
                        );
                        if (!mounted) return;
                        await _createCustomer(this.context);
                      },
                    );
                  }
                  final c = opts[i - 1];
                  return ListTile(
                    dense: true,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(c.fullName),
                    subtitle: _subtitleFor(c),
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
        widget.controller.text = c.fullName;
        widget.onSelected(c);
        FocusScope.of(context).nextFocus();
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
