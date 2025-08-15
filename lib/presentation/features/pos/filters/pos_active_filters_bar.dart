// Renders active POS filters as chips with clear actions.
import 'package:flutter/material.dart';
import 'pos_filters.dart';

class PosActiveFiltersBar extends StatelessWidget {
  final PosFilters filters;
  final VoidCallback onClearAll;
  final VoidCallback onToggleStock;
  final VoidCallback onClearCategory;
  final VoidCallback onClearMin;
  final VoidCallback onClearMax;

  const PosActiveFiltersBar({
    super.key,
    required this.filters,
    required this.onClearAll,
    required this.onToggleStock,
    required this.onClearCategory,
    required this.onClearMin,
    required this.onClearMax,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (filters.inStockOnly) {
      chips.add(
        FilterChip(
          label: const Text('En stock'),
          selected: true,
          onSelected: (_) => onToggleStock(),
        ),
      );
    }
    if ((filters.categoryId ?? '').isNotEmpty) {
      chips.add(
        InputChip(
          label: Text('Catégorie: ${filters.categoryLabel ?? '—'}'),
          onDeleted: onClearCategory,
        ),
      );
    }
    if (filters.minPriceCents != null) {
      chips.add(
        InputChip(
          label: Text('Prix ≥ ${(filters.minPriceCents! ~/ 100)}'),
          onDeleted: onClearMin,
        ),
      );
    }
    if (filters.maxPriceCents != null) {
      chips.add(
        InputChip(
          label: Text('Prix ≤ ${(filters.maxPriceCents! ~/ 100)}'),
          onDeleted: onClearMax,
        ),
      );
    }
    chips.add(
      ActionChip(
        avatar: const Icon(Icons.filter_alt_off),
        label: const Text('Effacer les filtres'),
        onPressed: onClearAll,
      ),
    );
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}
