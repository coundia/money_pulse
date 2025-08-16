// Filters bar with search field, company dropdown placeholder, and debt chips.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_filters_providers.dart';

class CustomerFiltersBar extends ConsumerWidget {
  final TextEditingController searchCtrl;
  const CustomerFiltersBar({super.key, required this.searchCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDebt = ref.watch(customerHasDebtFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onSubmitted: (v) {
                    ref.read(customerSearchProvider.notifier).state = v;
                    ref.read(customerPageIndexProvider.notifier).state = 0;
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    hintText: 'Rechercher par nom, téléphone, email, code',
                    suffixIcon: IconButton(
                      tooltip: 'Effacer',
                      onPressed: () {
                        searchCtrl.clear();
                        ref.read(customerSearchProvider.notifier).state = '';
                        ref.read(customerPageIndexProvider.notifier).state = 0;
                      },
                      icon: const Icon(Icons.clear),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: hasDebt == null,
                  onSelected: (_) =>
                      ref.read(customerHasDebtFilterProvider.notifier).state =
                          null,
                ),
                FilterChip(
                  label: const Text('Avec dette'),
                  selected: hasDebt == true,
                  onSelected: (_) =>
                      ref.read(customerHasDebtFilterProvider.notifier).state =
                          true,
                ),
                FilterChip(
                  label: const Text('Sans dette'),
                  selected: hasDebt == false,
                  onSelected: (_) =>
                      ref.read(customerHasDebtFilterProvider.notifier).state =
                          false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
