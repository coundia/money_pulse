import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final bool lockToItems;
  final ValueChanged<bool>? onToggleLock;
  final VoidCallback onChanged;
  final String preview;

  const AmountField({
    super.key,
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
