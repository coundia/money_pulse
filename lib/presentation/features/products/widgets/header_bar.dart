import 'package:flutter/material.dart';
import '../filters/product_filters.dart';

class HeaderBar extends StatelessWidget {
  final int total;
  final TextEditingController searchCtrl;
  final VoidCallback onOpenFilters;
  final ProductFilters filters;
  final VoidCallback onClearFilters;

  const HeaderBar({
    super.key,
    required this.total,
    required this.searchCtrl,
    required this.onOpenFilters,
    required this.filters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final pills = <Widget>[
      Chip(
        avatar: const Icon(Icons.inventory_2_outlined, size: 18),
        label: Text('Total: $total'),
      ),
      if (filters.hasAny)
        InputChip(
          avatar: const Icon(Icons.filter_alt, size: 18),
          label: const Text('Filtres actifs'),
          onPressed: onOpenFilters,
          onDeleted: onClearFilters,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Produits', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [Wrap(spacing: 8, children: pills)]),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher par nom, code ou EAN',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
