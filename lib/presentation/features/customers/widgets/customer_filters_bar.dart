// Filters bar with search, company dropdown, has-debt chips, sort chips, and reset action.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_filters_providers.dart';
import '../providers/customer_filters_data_providers.dart';

class CustomerFiltersBar extends ConsumerWidget {
  final TextEditingController searchCtrl;
  const CustomerFiltersBar({super.key, required this.searchCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDebt = ref.watch(customerHasDebtFilterProvider);
    final sortMode = ref.watch(customerSortModeProvider);
    final companyAsync = ref.watch(companyFilterOptionsProvider);
    final selectedCompanyId = ref.watch(customerCompanyFilterProvider);

    void resetPaging() =>
        ref.read(customerPageIndexProvider.notifier).state = 0;

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
                    resetPaging();
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    hintText: 'Rechercher par nom, téléphone, email',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Lancer la recherche',
                          onPressed: () {
                            ref.read(customerSearchProvider.notifier).state =
                                searchCtrl.text;
                            resetPaging();
                          },
                          icon: const Icon(Icons.arrow_forward),
                        ),
                        IconButton(
                          tooltip: 'Effacer',
                          onPressed: () {
                            searchCtrl.clear();
                            ref.read(customerSearchProvider.notifier).state =
                                '';
                            resetPaging();
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: companyAsync.when(
                  data: (companies) {
                    final items = <DropdownMenuItem<String?>>[
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Toutes sociétés'),
                      ),
                      ...companies.map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            (c.name ?? '').isNotEmpty
                                ? c.name!
                                : (c.code ?? 'Société'),
                          ),
                        ),
                      ),
                    ];
                    return InputDecorator(
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Société',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: selectedCompanyId,
                          items: items,
                          onChanged: (v) {
                            ref
                                    .read(
                                      customerCompanyFilterProvider.notifier,
                                    )
                                    .state =
                                v;
                            resetPaging();
                          },
                        ),
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erreur: $e'),
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Tous'),
                    selected: hasDebt == null,
                    onSelected: (_) {
                      ref.read(customerHasDebtFilterProvider.notifier).state =
                          null;
                      resetPaging();
                    },
                  ),
                  FilterChip(
                    label: const Text('Avec dette'),
                    selected: hasDebt == true,
                    onSelected: (_) {
                      ref.read(customerHasDebtFilterProvider.notifier).state =
                          true;
                      resetPaging();
                    },
                  ),
                  FilterChip(
                    label: const Text('Sans dette'),
                    selected: hasDebt == false,
                    onSelected: (_) {
                      ref.read(customerHasDebtFilterProvider.notifier).state =
                          false;
                      resetPaging();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Récents'),
                    selected: sortMode == CustomerSortMode.recent,
                    onSelected: (_) {
                      ref.read(customerSortModeProvider.notifier).state =
                          CustomerSortMode.recent;
                      resetPaging();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('A–Z'),
                    selected: sortMode == CustomerSortMode.az,
                    onSelected: (_) {
                      ref.read(customerSortModeProvider.notifier).state =
                          CustomerSortMode.az;
                      resetPaging();
                    },
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  searchCtrl.clear();
                  ref.read(customerSearchProvider.notifier).state = '';
                  ref.read(customerCompanyFilterProvider.notifier).state = null;
                  ref.read(customerHasDebtFilterProvider.notifier).state = null;
                  ref.read(customerSortModeProvider.notifier).state =
                      CustomerSortMode.recent;
                  resetPaging();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Réinitialiser'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
