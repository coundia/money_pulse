// Customer list page using compact CustomerTile, active filters bar, refresh and filter drawers.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'providers/customer_list_providers.dart';
import 'providers/customer_filters_providers.dart';
import 'widgets/customer_filters_panel.dart';
import 'widgets/active_filters_bar.dart';
import 'widgets/customer_tile.dart';
import 'customer_form_panel.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  Future<void> _refresh() async {
    ref.invalidate(customerListProvider);
    ref.invalidate(customerCountProvider);
    await ref.read(customerListProvider.future).catchError((_) {});
  }

  void _clearAllFiltersAndRefresh() {
    ref.read(customerSearchProvider.notifier).state = '';
    ref.read(customerCompanyFilterProvider.notifier).state = null;
    ref.read(customerHasDebtFilterProvider.notifier).state = null;
    ref.read(customerSortModeProvider.notifier).state = CustomerSortMode.recent;
    ref.read(customerPageIndexProvider.notifier).state = 0;
    _refresh();
  }

  int _activeFiltersCount(WidgetRef ref) {
    final search = ref.watch(customerSearchProvider);
    final companyId = ref.watch(customerCompanyFilterProvider);
    final hasDebt = ref.watch(customerHasDebtFilterProvider);
    final sort = ref.watch(customerSortModeProvider);
    int c = 0;
    if (search.trim().isNotEmpty) c++;
    if ((companyId ?? '').isNotEmpty) c++;
    if (hasDebt != null) c++;
    if (sort != CustomerSortMode.recent) c++;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(customerListProvider);
    final countAsync = ref.watch(customerCountProvider);
    final filtersCount = _activeFiltersCount(ref);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          if (filtersCount > 0)
            IconButton(
              tooltip: 'Réinitialiser les filtres',
              onPressed: _clearAllFiltersAndRefresh,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Filtres',
                  onPressed: () async {
                    final ok = await showRightDrawer<bool>(
                      context,
                      child: const CustomerFiltersPanel(),
                      widthFraction: 0.86,
                      heightFraction: 0.96,
                    );
                    if (ok == true) _refresh();
                  },
                  icon: const Icon(Icons.filter_list),
                ),
                if (filtersCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$filtersCount',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onError,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          ActiveFiltersBar(onAnyChange: _refresh),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: listAsync.when(
                data: (rows) {
                  if (rows.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 48),
                        Icon(
                          Icons.group_outlined,
                          size: 56,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        const Center(child: Text('Aucun client')),
                        const SizedBox(height: 48),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) =>
                        CustomerTile(customer: rows[i], onChanged: _refresh),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur: $e')),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: countAsync.maybeWhen(
              data: (c) => Align(
                alignment: Alignment.centerLeft,
                child: Text('$c élément(s)'),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showRightDrawer<bool>(
            context,
            child: const CustomerFormPanel(),
            widthFraction: 0.86,
            heightFraction: 0.96,
          );
          if (ok == true) _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
