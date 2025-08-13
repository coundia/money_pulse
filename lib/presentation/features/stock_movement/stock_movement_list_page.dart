/// List page orchestrating load/search/navigate and right drawers for StockMovement CRUD.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import '../../shared/formatters.dart';
import '../../../domain/stock/repositories/stock_movement_repository.dart';
import 'providers/stock_movement_repo_provider.dart';
import 'stock_movement_view_panel.dart';
import 'stock_movement_form_panel.dart';
import 'widgets/stock_movement_tile.dart';
import 'widgets/stock_movement_context_menu.dart';
import 'providers/stock_movement_list_provider.dart';

class StockMovementListPage extends ConsumerStatefulWidget {
  const StockMovementListPage({super.key});

  @override
  ConsumerState<StockMovementListPage> createState() =>
      _StockMovementListPageState();
}

class _StockMovementListPageState extends ConsumerState<StockMovementListPage> {
  final _searchCtrl = TextEditingController();

  Future<void> _openView(StockMovementRow row) async {
    await showRightDrawer(
      context,
      child: StockMovementViewPanel(itemId: row.id),
    );
  }

  Future<void> _openForm({String? id}) async {
    final changed = await showRightDrawer<bool>(
      context,
      child: StockMovementFormPanel(itemId: id),
    );
    if (changed == true && mounted) {
      ref.invalidate(stockMovementListProvider);
    }
  }

  Future<void> _openDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Confirmez-vous la suppression ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).maybePop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).maybePop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final repo = ref.read(stockMovementRepoProvider);
      await repo.delete(id);
      if (mounted) ref.invalidate(stockMovementListProvider);
    }
  }

  void _onAction(StockMovementRow row, StockMovementMenuAction a) {
    switch (a) {
      case StockMovementMenuAction.view:
        _openView(row);
        break;
      case StockMovementMenuAction.edit:
        _openForm(id: row.id);
        break;
      case StockMovementMenuAction.delete:
        _openDelete(row.id);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(stockMovementListProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mouvements de stock'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(stockMovementListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
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
                    child: TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (q) =>
                          ref.read(stockMovementQueryProvider.notifier).state =
                              q.trim(),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par produit, société ou type…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer',
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ref
                                          .read(
                                            stockMovementQueryProvider.notifier,
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
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'Rechercher',
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          ref.read(stockMovementQueryProvider.notifier).state =
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
                  onRefresh: () async =>
                      ref.invalidate(stockMovementListProvider),
                  child: asyncList.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            'Aucun mouvement',
                            style: theme.textTheme.bodyLarge,
                          ),
                        );
                      }
                      return LayoutBuilder(
                        builder: (context, c) {
                          final isGrid = c.maxWidth >= 720;
                          if (isGrid) {
                            final cross = c.maxWidth ~/ 340;
                            return GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cross.clamp(2, 6),
                                    childAspectRatio: 3.2,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                  ),
                              itemCount: items.length,
                              itemBuilder: (_, i) {
                                final row = items[i];
                                return Card(
                                  child: StockMovementTile(
                                    row: row,
                                    onTap: () => _openView(row),
                                    onMenu: (a) => _onAction(row, a),
                                  ),
                                );
                              },
                            );
                          }
                          return ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final row = items[i];
                              return StockMovementTile(
                                row: row,
                                onTap: () => _openView(row),
                                onMenu: (a) => _onAction(row, a),
                              );
                            },
                          );
                        },
                      );
                    },
                    error: (e, st) => ListView(
                      padding: const EdgeInsets.all(16),
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
                                ref.invalidate(stockMovementListProvider),
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
