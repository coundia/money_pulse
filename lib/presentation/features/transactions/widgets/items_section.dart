import 'package:flutter/material.dart';
import 'package:jaayko/presentation/shared/formatters.dart';
import '../models/tx_item.dart';

class ItemsSection extends StatelessWidget {
  final List<TxItem> items;
  final int totalCents;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final VoidCallback onTapItem;
  final VoidCallback onCreateProduct; // NEW

  const ItemsSection({
    super.key,
    required this.items,
    required this.totalCents,
    required this.onPick,
    required this.onClear,
    required this.onTapItem,
    required this.onCreateProduct, // NEW
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Two primary actions on one row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.playlist_add_check),
                label: Text(
                  items.isEmpty
                      ? 'Sélectionner des produits'
                      : 'Modifier la sélection',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCreateProduct, // NEW
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Nouveau produit'),
              ),
            ),
          ],
        ),

        // Summary & clear actions (wrap to avoid overflow)
        if (items.isNotEmpty) const SizedBox(height: 8),
        if (items.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(label: Text('${items.length} produit(s)')),
              Chip(
                label: Text('Total: ${Formatters.amountFromCents(totalCents)}'),
              ),
              ActionChip(
                avatar: const Icon(Icons.delete_sweep),
                label: const Text('Vider'),
                onPressed: onClear,
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
