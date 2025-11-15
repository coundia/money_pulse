// lib/presentation/features/transactions/detail/widgets/items_section.dart

import 'package:flutter/material.dart';
import 'package:jaayko/presentation/shared/formatters.dart';

class ItemRowData {
  final String label;
  final int quantity;
  final int unitPrice;
  final int total;

  ItemRowData({
    required this.label,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}

class ItemsSection extends StatelessWidget {
  final String title;
  final List<ItemRowData> items;
  final Color accent;

  const ItemsSection({
    super.key,
    required this.title,
    required this.items,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            ListTile(
              title: Text(title),
              trailing: _TypePillSmallLegacy(
                label: '${items.length} article(s)',
                color: accent,
              ),
            ),
            const Divider(height: 1),
            ...items.map(
              (it) => ListTile(
                dense: true,
                leading: const Icon(Icons.shopping_bag_outlined),
                title: Text(
                  it.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${it.quantity} × ${Formatters.amountFromCents(it.unitPrice)}',
                ),
                trailing: Text(
                  Formatters.amountFromCents(it.total),
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Petit pill interne pour l’en-tête de la section (pour éviter une dépendance circulaire avec pills.dart)
class _TypePillSmallLegacy extends StatelessWidget {
  final String label;
  final Color color;
  const _TypePillSmallLegacy({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(0.10);
    final fg = color.withOpacity(0.90);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fg.withOpacity(0.28), width: 0.7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
