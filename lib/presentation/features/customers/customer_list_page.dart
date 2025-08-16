// Customer list page with SRP filters bar and updated list UX.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'providers/customer_list_providers.dart';
import 'providers/customer_filters_providers.dart';
import 'customer_form_panel.dart';
import 'customer_view_panel.dart';
import 'customer_delete_panel.dart';
import 'widgets/customer_context_menu.dart';
import 'widgets/customer_filters_bar.dart';

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
      appBar: AppBar(title: const Text('Clients')),
      body: Column(
        children: [
          CustomerFiltersBar(searchCtrl: _searchCtrl),
          const Divider(height: 1),
          Expanded(
            child: listAsync.when(
              data: (rows) {
                if (rows.isEmpty)
                  return const Center(child: Text('Aucun client'));
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = rows[i];
                    return ListTile(
                      onTap: () => showRightDrawer(
                        context,
                        child: CustomerViewPanel(customerId: c.id),
                        widthFraction: 0.86,
                        heightFraction: 0.96,
                      ),
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(
                        c.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        (c.phone ?? '').isNotEmpty ? c.phone! : (c.email ?? ''),
                      ),
                      trailing: CustomerContextMenu(
                        onSelected: (a) async {
                          switch (a) {
                            case CustomerMenuAction.view:
                              await showRightDrawer(
                                context,
                                child: CustomerViewPanel(customerId: c.id),
                                widthFraction: 0.86,
                                heightFraction: 0.96,
                              );
                              break;
                            case CustomerMenuAction.edit:
                              final ok = await showRightDrawer<bool>(
                                context,
                                child: CustomerFormPanel(initial: c),
                                widthFraction: 0.86,
                                heightFraction: 0.96,
                              );
                              if (ok == true) _refresh();
                              break;
                            case CustomerMenuAction.delete:
                              final ok = await showRightDrawer<bool>(
                                context,
                                child: CustomerDeletePanel(customerId: c.id),
                                widthFraction: 0.86,
                                heightFraction: 0.6,
                              );
                              if (ok == true) _refresh();
                              break;
                          }
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
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
