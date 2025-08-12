import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/domain/company/entities/company.dart';
import 'package:money_pulse/presentation/features/companies/company_form_panel.dart';
import 'package:money_pulse/presentation/features/companies/providers/company_list_providers.dart';
import 'package:money_pulse/presentation/features/companies/widgets/company_tile.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

class CompanyListPage extends ConsumerWidget {
  const CompanyListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(companyListProvider);
    final countAsync = ref.watch(companyCountProvider);
    final searchCtrl = TextEditingController(
      text: ref.read(companySearchProvider),
    );

    void _refresh() {
      ref.invalidate(companyListProvider);
      ref.invalidate(companyCountProvider);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sociétés')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    onSubmitted: (v) {
                      ref.read(companySearchProvider.notifier).state = v;
                      ref.read(companyPageIndexProvider.notifier).state = 0;
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      hintText: 'Rechercher par code, nom, téléphone, email',
                      suffixIcon: IconButton(
                        tooltip: 'Effacer',
                        onPressed: () {
                          searchCtrl.clear();
                          ref.read(companySearchProvider.notifier).state = '';
                          ref.read(companyPageIndexProvider.notifier).state = 0;
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
          const Divider(height: 1),
          Expanded(
            child: listAsync.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('Aucune société'));
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = rows[i];
                    return CompanyTile(
                      company: c,
                      // Enrichir menu ici si besoin
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showRightDrawer<bool>(
            context,
            child: const CompanyFormPanel(),
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
