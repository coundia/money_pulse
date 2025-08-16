// Customer list page with search, active-filters bar (with onAnyChange), and right-drawer filter panel.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/customer_list_providers.dart';
import 'widgets/customer_tile.dart';
import 'customer_form_panel.dart';
import 'widgets/customer_filters_panel.dart';
import 'widgets/active_filters_bar.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: ref.read(customerSearchProvider));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(customerListProvider);
    ref.invalidate(customerCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(customerListProvider);
    final countAsync = ref.watch(customerCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Filtres',
            onPressed: () async {
              final changed = await showRightDrawer<bool>(
                context,
                child: const CustomerFiltersPanel(),
                widthFraction: 0.86,
                heightFraction: 0.96,
              );
              if (changed == true) _refresh();
            },
            icon: const Icon(Icons.filter_alt),
          ),
          IconButton(
            tooltip: 'Ajouter',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final ok = await showRightDrawer<bool>(
                context,
                child: const CustomerFormPanel(),
                widthFraction: 0.86,
                heightFraction: 0.96,
              );
              if (ok == true) _refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (v) {
                      ref.read(customerSearchProvider.notifier).state = v;
                      ref.read(customerPageIndexProvider.notifier).state = 0;
                      _refresh(); // refresh on search submit
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      hintText: 'Rechercher par nom, téléphone, email, code',
                      suffixIcon: IconButton(
                        tooltip: 'Effacer',
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(customerSearchProvider.notifier).state = '';
                          ref.read(customerPageIndexProvider.notifier).state =
                              0;
                          _refresh();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                countAsync.maybeWhen(
                  data: (c) => Text('$c élément(s)'),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // IMPORTANT: Active filters
          ActiveFiltersBar(onAnyChange: _refresh),

          const Divider(height: 1),
          Expanded(
            child: listAsync.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('Aucun client'));
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => CustomerTile(customer: rows[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
