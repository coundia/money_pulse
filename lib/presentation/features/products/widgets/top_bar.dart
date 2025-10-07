import 'package:flutter/material.dart';

import '../filters/product_filters.dart';

class TopBar extends StatelessWidget {
  final int total;
  final TextEditingController searchCtrl;
  final ProductFilters filters;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearFilters;
  final Future<void> Function() onRefresh;
  final VoidCallback onUnfocus;

  const TopBar({
    super.key,
    required this.total,
    required this.searchCtrl,
    required this.filters,
    required this.onOpenFilters,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onUnfocus,
  });

  @override
  Widget build(BuildContext context) {
    final isFiltered = filters != const ProductFilters();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Produits', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text('Total: $total'),
            ),
            ActionChip(
              avatar: const Icon(Icons.tune),
              label: const Text('Filtres'),
              onPressed: () {
                onUnfocus();
                onOpenFilters();
              },
            ),
            if (isFiltered)
              ActionChip(
                avatar: const Icon(Icons.filter_alt_off),
                label: const Text('Effacer les filtres'),
                onPressed: () {
                  onUnfocus();
                  onClearFilters();
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.refresh),
              label: const Text('Rafraîchir'),
              onPressed: () {
                onUnfocus();
                onRefresh();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchCtrl,
                autofocus: false,
                onTapOutside: (_) => onUnfocus(),
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchCtrl.clear();
                            onUnfocus();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onUnfocus(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
