import 'package:flutter/material.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import '../models/tx_item.dart';

class ItemsSection extends StatelessWidget {
  final List<TxItem> items;
  final int totalCents;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final VoidCallback onTapItem;

  const ItemsSection({
    super.key,
    required this.items,
    required this.totalCents,
    required this.onPick,
    required this.onClear,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  items.isEmpty
                      ? 'Ajouter des produits'
                      : 'Modifier les produits',
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (items.isNotEmpty)
              Wrap(
                spacing: 6,
                children: [
                  Chip(label: Text('${items.length} produit(s)')),
                  Chip(
                    label: Text(
                      'Total: ${Formatters.amountFromCents(totalCents)}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Vider',
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_sweep),
                  ),
                ],
              ),
          ],
        ),
        if (items.isNotEmpty) const SizedBox(height: 8),
        if (items.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final it = items[i];
              final lineTotal = it.unitPriceCents * it.quantity;
              return ListTile(
                dense: true,
                leading: const Icon(Icons.shopping_bag),
                title: Text(it.label.isEmpty ? 'Produit' : it.label),
                subtitle: Text(
                  'Qté: ${it.quantity} • PU: ${Formatters.amountFromCents(it.unitPriceCents)}',
                ),
                trailing: Text(Formatters.amountFromCents(lineTotal)),
                onTap: onTapItem,
              );
            },
          ),
      ],
    );
  }
}
