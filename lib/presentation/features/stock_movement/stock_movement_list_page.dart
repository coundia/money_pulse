/// Read-only stock movements list with French UI and amounts (PU & Total),
/// local filters (type/date/quantity), search, responsive grid/list,
/// summary chips, and right-drawer view. Add-only; no edit/delete.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import '../../shared/formatters.dart';
import '../../../domain/stock/repositories/stock_movement_repository.dart';
import 'stock_movement_view_panel.dart';
import 'stock_movement_form_panel.dart';
import 'providers/stock_movement_list_provider.dart';

class StockMovementListPage extends ConsumerStatefulWidget {
  const StockMovementListPage({super.key});

  @override
  ConsumerState<StockMovementListPage> createState() =>
      _StockMovementListPageState();
}

class _StockMovementListPageState extends ConsumerState<StockMovementListPage> {
  final _searchCtrl = TextEditingController();

  String _typeFilter = 'ALL';
  DateTimeRange? _dateRange;
  int _minQty = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openView(StockMovementRow row) async {
    await showRightDrawer(
      context,
      child: StockMovementViewPanel(itemId: row.id),
    );
  }

  Future<void> _openForm() async {
    final changed = await showRightDrawer<bool>(
      context,
      child: const StockMovementFormPanel(),
    );
    if (changed == true && mounted) {
      ref.invalidate(stockMovementListProvider);
    }
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

  void _pickRange() async {
    final now = DateTime.now();
    final initial =
        _dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initial,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _clearFilters() {
    setState(() {
      _typeFilter = 'ALL';
      _dateRange = null;
      _minQty = 0;
    });
  }

  List<StockMovementRow> _applyLocalFilters(List<StockMovementRow> base) {
    var items = base;

    if (_typeFilter != 'ALL') {
      items = items.where((e) => e.type == _typeFilter).toList();
    }
    if (_dateRange != null) {
      final start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
        999,
      );
      items = items
          .where(
            (e) =>
                e.createdAt.isAfter(
                  start.subtract(const Duration(milliseconds: 1)),
                ) &&
                e.createdAt.isBefore(end.add(const Duration(milliseconds: 1))),
          )
          .toList();
    }
    if (_minQty > 0) {
      items = items.where((e) => e.quantity >= _minQty).toList();
    }

    return items;
  }

  Map<String, int> _countByType(List<StockMovementRow> items) {
    final map = <String, int>{
      'IN': 0,
      'OUT': 0,
      'ALLOCATE': 0,
      'RELEASE': 0,
      'ADJUST': 0,
    };
    for (final it in items) {
      if (map.containsKey(it.type)) {
        map[it.type] = (map[it.type] ?? 0) + 1;
      }
    }
    return map;
  }

  Color _typeColor(BuildContext ctx, String type) {
    final cs = Theme.of(ctx).colorScheme;
    switch (type) {
      case 'IN':
        return cs.primary;
      case 'OUT':
        return cs.error;
      case 'ALLOCATE':
        return cs.tertiary;
      case 'RELEASE':
        return cs.secondary;
      case 'ADJUST':
        return cs.outline;
      default:
        return cs.onSurfaceVariant;
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
        onPressed: _openForm,
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
                      onSubmitted: (_) => _applySearch(),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par produit, société ou type…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer',
                                onPressed: _clearSearch,
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
                      onPressed: _applySearch,
                      icon: const Icon(Icons.search),
                      label: const Text('Rechercher'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _FiltersBar(
                typeFilter: _typeFilter,
                onTypeChanged: (t) => setState(() => _typeFilter = t),
                dateRange: _dateRange,
                onPickRange: _pickRange,
                minQty: _minQty,
                onMinQtyChanged: (v) => setState(() => _minQty = v),
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(stockMovementListProvider),
                  child: asyncList.when(
                    data: (itemsRaw) {
                      final items = _applyLocalFilters(itemsRaw);
                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            'Aucun mouvement',
                            style: theme.textTheme.bodyLarge,
                          ),
                        );
                      }

                      final counts = _countByType(items);
                      final sumQty = items.fold<int>(
                        0,
                        (p, e) => p + e.quantity,
                      );
                      final sumTotalCents = items.fold<int>(
                        0,
                        (p, e) => p + e.totalCents,
                      );
                      const typeLabels = {
                        'IN': 'Entrée',
                        'OUT': 'Sortie',
                        'ALLOCATE': 'Allocation',
                        'RELEASE': 'Libération',
                        'ADJUST': 'Ajustement',
                      };

                      return Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.list_alt, size: 18),
                                  label: Text('${items.length} élément(s)'),
                                ),
                                Chip(
                                  avatar: const Icon(Icons.summarize, size: 18),
                                  label: Text('Qté totale: $sumQty'),
                                ),
                                Chip(
                                  avatar: const Icon(Icons.payments, size: 18),
                                  label: Text(
                                    'Montant total: ${Formatters.amountFromCents(sumTotalCents)}',
                                  ),
                                ),
                                for (final t in [
                                  'IN',
                                  'OUT',
                                  'ALLOCATE',
                                  'RELEASE',
                                  'ADJUST',
                                ])
                                  Chip(
                                    avatar: Icon(
                                      Icons.circle,
                                      size: 12,
                                      color: _typeColor(context, t),
                                    ),
                                    label: Text(
                                      '${typeLabels[t]}: ${counts[t]}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final isGrid = c.maxWidth >= 720;
                                if (isGrid) {
                                  final cross = c.maxWidth ~/ 380;
                                  return GridView.builder(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: cross.clamp(2, 6),
                                          childAspectRatio: 3.6,
                                          mainAxisSpacing: 8,
                                          crossAxisSpacing: 8,
                                        ),
                                    itemCount: items.length,
                                    itemBuilder: (_, i) {
                                      final row = items[i];
                                      return _MovementCard(
                                        row: row,
                                        onTap: () => _openView(row),
                                        typeColor: _typeColor(
                                          context,
                                          row.type,
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
                                    return _MovementTile(
                                      row: row,
                                      onTap: () => _openView(row),
                                      typeColor: _typeColor(context, row.type),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
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

class _FiltersBar extends StatelessWidget {
  final String typeFilter;
  final ValueChanged<String> onTypeChanged;
  final DateTimeRange? dateRange;
  final VoidCallback onPickRange;
  final int minQty;
  final ValueChanged<int> onMinQtyChanged;
  final VoidCallback onClear;

  const _FiltersBar({
    required this.typeFilter,
    required this.onTypeChanged,
    required this.dateRange,
    required this.onPickRange,
    required this.minQty,
    required this.onMinQtyChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final chips = const ['ALL', 'IN', 'OUT', 'ALLOCATE', 'RELEASE', 'ADJUST'];
    const labels = {
      'ALL': 'Tous',
      'IN': 'Entrée',
      'OUT': 'Sortie',
      'ALLOCATE': 'Allocation',
      'RELEASE': 'Libération',
      'ADJUST': 'Ajustement',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text(
                'Type : ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                children: chips
                    .map(
                      (t) => ChoiceChip(
                        label: Text(labels[t] ?? t),
                        selected: typeFilter == t,
                        onSelected: (_) => onTypeChanged(t),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onPickRange,
              icon: const Icon(Icons.event),
              label: Text(
                dateRange == null
                    ? 'Période : Toutes'
                    : 'Période : ${_fmt(dateRange!.start)} → ${_fmt(dateRange!.end)}',
              ),
            ),
            DropdownButton<int>(
              value: minQty,
              onChanged: (v) => onMinQtyChanged(v ?? 0),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Qté min : 0')),
                DropdownMenuItem(value: 1, child: Text('Qté min : 1')),
                DropdownMenuItem(value: 5, child: Text('Qté min : 5')),
                DropdownMenuItem(value: 10, child: Text('Qté min : 10')),
                DropdownMenuItem(value: 50, child: Text('Qté min : 50')),
              ],
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Réinitialiser'),
            ),
          ],
        ),
      ],
    );
  }

  static String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }
}

class _MovementTile extends StatelessWidget {
  final StockMovementRow row;
  final VoidCallback onTap;
  final Color typeColor;
  const _MovementTile({
    required this.row,
    required this.onTap,
    required this.typeColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pu = Formatters.amountFromCents(row.unitPriceCents);
    final tot = Formatters.amountFromCents(row.totalCents);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: typeColor.withOpacity(0.12),
        foregroundColor: typeColor,
        child: Text(row.type.substring(0, 1)),
      ),
      title: Text(
        '${row.productLabel} • ${row.companyLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${row.type} • Qté: ${row.quantity} • PU: $pu • Total: $tot • ${Formatters.dateFull(row.createdAt)}',
      ),
      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
    );
  }
}

class _MovementCard extends StatelessWidget {
  final StockMovementRow row;
  final VoidCallback onTap;
  final Color typeColor;
  const _MovementCard({
    required this.row,
    required this.onTap,
    required this.typeColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pu = Formatters.amountFromCents(row.unitPriceCents);
    final tot = Formatters.amountFromCents(row.totalCents);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: typeColor.withOpacity(0.12),
              foregroundColor: typeColor,
              child: Text(row.type.substring(0, 1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.productLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.companyLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Chip(
                        label: Text(row.type),
                        avatar: Icon(Icons.circle, size: 12, color: typeColor),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text('Qté: ${row.quantity}'),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text('PU: $pu'),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text('Total: $tot'),
                        visualDensity: VisualDensity.compact,
                      ),
                      Chip(
                        label: Text(Formatters.dateFull(row.createdAt)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
