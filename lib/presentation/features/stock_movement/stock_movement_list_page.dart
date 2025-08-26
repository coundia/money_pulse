// Read-only stock movements page using SRP components: summary, filter sheet, list items and right drawer view.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import '../../../domain/stock/repositories/stock_movement_repository.dart';
import '../../shared/formatters.dart';
import 'widgets/movement_filter_sheet.dart';
import 'widgets/movement_filters.dart';
import 'widgets/movement_item.dart';
import 'widgets/movement_summary_bar.dart';
import 'providers/stock_movement_list_provider.dart';
import 'stock_movement_view_panel.dart';

class StockMovementListPage extends ConsumerStatefulWidget {
  const StockMovementListPage({super.key});

  @override
  ConsumerState<StockMovementListPage> createState() =>
      _StockMovementListPageState();
}

class _StockMovementListPageState extends ConsumerState<StockMovementListPage> {
  final _searchCtrl = TextEditingController();
  var _filters = const MovementFilters.initial();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openView(StockMovementRow row) async {
    await showRightDrawer(
      context,
      child: StockMovementViewPanel(itemId: row.id ?? "-"),
    );
  }

  void _applySearch() {
    ref.read(stockMovementQueryProvider.notifier).state = _searchCtrl.text
        .trim();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    ref.read(stockMovementQueryProvider.notifier).state = '';
    setState(() {});
  }

  void _openFilterSheet() async {
    final result = await showModalBottomSheet<MovementFilters>(
      context: context,
      isScrollControlled: true,
      builder: (c) => MovementFilterSheet(initial: _filters),
    );
    if (result != null) {
      setState(() => _filters = result);
    }
  }

  void _clearFilters() =>
      setState(() => _filters = const MovementFilters.initial());

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(stockMovementListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mouvements de stock'),
        actions: [
          IconButton(
            tooltip: 'Filtres',
            onPressed: _openFilterSheet,
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(stockMovementListProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applySearch(),
                    decoration: InputDecoration(
                      hintText: 'Rechercher produit, société ou type…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Effacer',
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _applySearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Rechercher'),
                ),
              ],
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              asyncList.when(
                data: (rows) => MovementSummaryBar(
                  source: rows,
                  filters: _filters,
                  onClearFilters: _clearFilters,
                ),
                error: (_, __) => const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(stockMovementListProvider),
                  child: asyncList.when(
                    data: (itemsRaw) {
                      final items = _filters.apply(itemsRaw);
                      if (items.isEmpty) {
                        return const _EmptyState();
                      }
                      return LayoutBuilder(
                        builder: (context, c) {
                          final isGrid = c.maxWidth >= 820;
                          if (isGrid) {
                            final cross = c.maxWidth ~/ 420;
                            return GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cross.clamp(2, 6),
                                    childAspectRatio: 3.8,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                  ),
                              itemCount: items.length,
                              itemBuilder: (_, i) => MovementCard(
                                row: items[i],
                                onTap: () => _openView(items[i]),
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) => MovementTile(
                              row: items[i],
                              onTap: () => _openView(items[i]),
                            ),
                          );
                        },
                      );
                    },
                    error: (e, st) => _ErrorState(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(stockMovementListProvider),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: t.colorScheme.outline),
          const SizedBox(height: 8),
          Text('Aucun mouvement', style: t.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 64),
        Icon(Icons.error_outline, size: 48, color: t.colorScheme.error),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Erreur de chargement',
            style: t.textTheme.titleMedium?.copyWith(
              color: t.colorScheme.error,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            message,
            style: t.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ),
      ],
    );
  }
}
