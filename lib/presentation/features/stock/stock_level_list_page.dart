// Stock level list page: orchestrates load/search/navigate and opens right drawers for view/edit/delete

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import '../../../domain/stock/repositories/stock_level_repository.dart';
import 'stock_level_view_panel.dart';
import 'stock_level_form_panel.dart';
import 'stock_level_delete_panel.dart';
import 'widgets/stock_level_tile.dart';
import 'widgets/stock_level_context_menu.dart';

import 'providers/stock_level_list_provider.dart';

class StockLevelListPage extends ConsumerStatefulWidget {
  const StockLevelListPage({super.key});

  @override
  ConsumerState<StockLevelListPage> createState() => _StockLevelListPageState();
}

class _StockLevelListPageState extends ConsumerState<StockLevelListPage> {
  final _searchCtrl = TextEditingController();

  Future<void> _openView(BuildContext context, StockLevelRow row) async {
    await showRightDrawer(context, child: StockLevelViewPanel(itemId: row.id));
  }

  Future<void> _openForm(BuildContext context, {String? id}) async {
    final changed = await showRightDrawer<bool>(
      context,
      child: StockLevelFormPanel(itemId: id),
    );
    if (changed == true && mounted) {
      ref.invalidate(stockLevelListProvider);
    }
  }

  Future<void> _openDelete(BuildContext context, String id) async {
    final deleted = await showRightDrawer<bool>(
      context,
      child: StockLevelDeletePanel(itemId: id),
    );
    if (deleted == true && mounted) {
      ref.invalidate(stockLevelListProvider);
    }
  }

  void _onAction(
    BuildContext context,
    StockLevelRow row,
    StockLevelMenuAction a,
  ) {
    switch (a) {
      case StockLevelMenuAction.view:
        _openView(context, row);
        break;
      case StockLevelMenuAction.edit:
        _openForm(context, id: row.id);
        break;
      case StockLevelMenuAction.delete:
        _openDelete(context, row.id);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(stockLevelListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Niveaux de stock'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(stockLevelListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        label: const Text('Ajouter'),
        icon: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Champ de recherche',
                      child: TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (q) =>
                            ref.read(stockLevelQueryProvider.notifier).state = q
                                .trim(),
                        decoration: InputDecoration(
                          hintText: 'Rechercher par produit ou entreprise…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Effacer',
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    ref
                                            .read(
                                              stockLevelQueryProvider.notifier,
                                            )
                                            .state =
                                        '';
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'Rechercher',
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          ref.read(stockLevelQueryProvider.notifier).state =
                              _searchCtrl.text.trim(),
                      icon: const Icon(Icons.search),
                      label: const Text('Rechercher'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(stockLevelListProvider),
                  child: asyncList.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            'Aucune donnée de stock',
                            style: theme.textTheme.bodyLarge,
                          ),
                        );
                      }
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isGrid = constraints.maxWidth >= 720;
                          if (isGrid) {
                            final cross = constraints.maxWidth ~/ 320;
                            return GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cross.clamp(2, 6),
                                    childAspectRatio: 3.2,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                  ),
                              itemCount: items.length,
                              itemBuilder: (c, i) {
                                final row = items[i];
                                return StockLevelTile(
                                  row: row,
                                  onTap: () => _openView(context, row),
                                  onMenu: (a) => _onAction(context, row, a),
                                );
                              },
                            );
                          }
                          return ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (c, i) {
                              final row = items[i];
                              return StockLevelTile(
                                row: row,
                                onTap: () => _openView(context, row),
                                onMenu: (a) => _onAction(context, row, a),
                              );
                            },
                          );
                        },
                      );
                    },
                    error: (e, st) => ListView(
                      children: [
                        const SizedBox(height: 64),
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Erreur de chargement',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            e.toString(),
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                ref.invalidate(stockLevelListProvider),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer'),
                          ),
                        ),
                      ],
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final now = DateTime.now();
                  return Text(
                    'Mis à jour ${Formatters.timeHm(now)}',
                    style: theme.textTheme.bodySmall,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
