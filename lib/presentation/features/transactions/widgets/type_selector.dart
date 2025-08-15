// Segmented type selector for transaction kind (debit, credit, debt, repayment, loan).
import 'package:flutter/material.dart';

enum TxKind { debit, credit, debt, remboursement, pret }

extension TxKindLabels on TxKind {
  String get label {
    switch (this) {
      case TxKind.debit:
        return 'Dépense';
      case TxKind.credit:
        return 'Revenu';
      case TxKind.debt:
        return 'Dette';
      case TxKind.remboursement:
        return 'Remboursement';
      case TxKind.pret:
        return 'Prêt';
    }
  }
}

class TypeSelector extends StatelessWidget {
  final TxKind value;
  final ValueChanged<TxKind> onChanged;

  const TypeSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final kinds = TxKind.values;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kinds
          .map(
            (k) => ChoiceChip(
              label: Text(k.label),
              selected: value == k,
              onSelected: (_) => onChanged(k),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
          .toList(),
    );
  }
}
