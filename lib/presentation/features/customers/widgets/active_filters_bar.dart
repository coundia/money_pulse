// Compact bar showing active filters as removable chips and a reset action.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jaayko/domain/company/entities/company.dart';
import '../providers/customer_filters_providers.dart';
import '../providers/customer_filters_data_providers.dart';

class ActiveFiltersBar extends ConsumerWidget {
  final VoidCallback onAnyChange;
  const ActiveFiltersBar({super.key, required this.onAnyChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(customerSearchProvider);
    final companyId = ref.watch(customerCompanyFilterProvider);
    final hasDebt = ref.watch(customerHasDebtFilterProvider);
    final sort = ref.watch(customerSortModeProvider);
    final companiesAsync = ref.watch(companyFilterOptionsProvider);

    final hasAny =
        search.trim().isNotEmpty ||
        (companyId ?? '').isNotEmpty ||
        hasDebt != null ||
        sort != CustomerSortMode.recent;

    if (!hasAny) return const SizedBox.shrink();

    void resetPaging() =>
        ref.read(customerPageIndexProvider.notifier).state = 0;

    void clearAll() {
      ref.read(customerSearchProvider.notifier).state = '';
      ref.read(customerCompanyFilterProvider.notifier).state = null;
      ref.read(customerHasDebtFilterProvider.notifier).state = null;
      ref.read(customerSortModeProvider.notifier).state =
          CustomerSortMode.recent;
      resetPaging();
      onAnyChange();
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: -6,
                children: [
                  if (search.trim().isNotEmpty)
                    InputChip(
                      label: Text('Recherche: ${search.trim()}'),
                      onDeleted: () {
                        ref.read(customerSearchProvider.notifier).state = '';
                        resetPaging();
                        onAnyChange();
                      },
                    ),
                  if ((companyId ?? '').isNotEmpty)
                    companiesAsync.when(
                      data: (companies) {
                        Company? selected;
                        for (final c in companies) {
                          if (c.id == companyId) {
                            selected = c;
                            break;
                          }
                        }
                        final label = selected == null
                            ? '—'
                            : ((selected.name ?? '').isNotEmpty
                                  ? selected.name!
                                  : (selected.code ?? 'Société'));
                        return InputChip(
                          label: Text('Société: $label'),
                          onDeleted: () {
                            ref
                                    .read(
                                      customerCompanyFilterProvider.notifier,
                                    )
                                    .state =
                                null;
                            resetPaging();
                            onAnyChange();
                          },
                        );
                      },
                      loading: () => const InputChip(label: Text('Société: …')),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                  if (sort != CustomerSortMode.recent)
                    InputChip(
                      label: const Text('Tri: A–Z'),
                      onDeleted: () {
                        ref.read(customerSortModeProvider.notifier).state =
                            CustomerSortMode.recent;
                        resetPaging();
                        onAnyChange();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: clearAll,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Réinitialiser'),
            ),
          ],
        ),
      ),
    );
  }
}
