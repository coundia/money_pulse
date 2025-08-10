import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';

import 'models/txn_search_filters.dart';
import 'widgets/txn_filter_sheet.dart';

class TxnSearchDelegate extends SearchDelegate<TransactionEntry?> {
  final List<TransactionEntry> items;

  // État des filtres
  final ValueNotifier<TxnFilterState> _filter = ValueNotifier<TxnFilterState>(
    const TxnFilterState(),
  );

  TxnSearchDelegate(this.items);

  // Pipeline de filtres pour la LISTE affichée
  List<TransactionEntry> _applyFilters(String q, TxnFilterState f) {
    final query = q.trim().toLowerCase();

    Iterable<TransactionEntry> it = items;

    // Type
    switch (f.type) {
      case TxnTypeFilter.expense:
        it = it.where((e) => e.typeEntry == 'DEBIT');
        break;
      case TxnTypeFilter.income:
        it = it.where((e) => e.typeEntry == 'CREDIT');
        break;
      case TxnTypeFilter.all:
        break;
    }

    // Date range
    if (f.from != null) {
      final start = DateTime(f.from!.year, f.from!.month, f.from!.day);
      it = it.where((e) => !e.dateTransaction.isBefore(start));
    }
    if (f.to != null) {
      final end = DateTime(f.to!.year, f.to!.month, f.to!.day, 23, 59, 59, 999);
      it = it.where((e) => !e.dateTransaction.isAfter(end));
    }

    // Amount range
    if (f.minCents != null) it = it.where((e) => e.amount >= f.minCents!);
    if (f.maxCents != null) it = it.where((e) => e.amount <= f.maxCents!);

    // Query texte
    if (query.isNotEmpty) {
      it = it.where((e) {
        final text = '${e.code ?? ''} ${e.description ?? ''}'.toLowerCase();
        return text.contains(query);
      });
    }

    // Tri
    final list = it.toList();
    switch (f.sortBy) {
      case TxnSortBy.dateDesc:
        list.sort((a, b) => b.dateTransaction.compareTo(a.dateTransaction));
        break;
      case TxnSortBy.dateAsc:
        list.sort((a, b) => a.dateTransaction.compareTo(b.dateTransaction));
        break;
      case TxnSortBy.amountDesc:
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case TxnSortBy.amountAsc:
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }
    return list;
  }

  // Calcul NET (toujours CREDIT − DEBIT) en ignorant le filtre "type"
  int _computeNetCents(String q, TxnFilterState f) {
    final base = _applyFilters(q, f.copyWith(type: TxnTypeFilter.all));
    final credit = base
        .where((e) => e.typeEntry == 'CREDIT')
        .fold<int>(0, (p, e) => p + e.amount);
    final debit = base
        .where((e) => e.typeEntry == 'DEBIT')
        .fold<int>(0, (p, e) => p + e.amount);
    return credit - debit;
  }

  String _formatWhen(DateTime d) => DateFormat.yMMMd().add_Hm().format(d);
  String _amount(int cents, {bool withSign = true, required bool debit}) {
    final sign = '';
    // !withSign ? '' : (debit ? '-' : '+');
    return '$sign${cents ~/ 100}';
  }

  InlineSpan _highlight(String text, String q, TextStyle base, TextStyle hi) {
    if (q.isEmpty) return TextSpan(text: text, style: base);
    final lower = text.toLowerCase();
    final query = q.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(query, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start), style: base));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: base));
      }
      spans.add(
        TextSpan(text: text.substring(idx, idx + query.length), style: hi),
      );
      start = idx + query.length;
    }
    return TextSpan(children: spans);
  }

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<TxnFilterState>(
      valueListenable: _filter,
      builder: (context, f, _) {
        final list = _applyFilters(query, f);
        final net = _computeNetCents(query, f);
        final netColor = net >= 0 ? Colors.green : Colors.red;

        return Column(
          children: [
            // Quick controls
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: f.type == TxnTypeFilter.all,
                    onSelected: (selected) {
                      if (selected)
                        _filter.value = f.copyWith(type: TxnTypeFilter.all);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Expense'),
                    selected: f.type == TxnTypeFilter.expense,
                    onSelected: (selected) {
                      if (selected)
                        _filter.value = f.copyWith(type: TxnTypeFilter.expense);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Income'),
                    selected: f.type == TxnTypeFilter.income,
                    onSelected: (selected) {
                      // ✅ Fix: en cliquant sur INCOME, il est bien sélectionné
                      if (selected)
                        _filter.value = f.copyWith(type: TxnTypeFilter.income);
                    },
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: Text(switch (f.sortBy) {
                      TxnSortBy.dateDesc => 'Date ↓',
                      TxnSortBy.dateAsc => 'Date ↑',
                      TxnSortBy.amountDesc => 'Amount ↓',
                      TxnSortBy.amountAsc => 'Amount ↑',
                    }),
                    selected: true,
                    onSelected: (_) {
                      final order = {
                        TxnSortBy.dateDesc: TxnSortBy.dateAsc,
                        TxnSortBy.dateAsc: TxnSortBy.amountDesc,
                        TxnSortBy.amountDesc: TxnSortBy.amountAsc,
                        TxnSortBy.amountAsc: TxnSortBy.dateDesc,
                      };
                      _filter.value = f.copyWith(sortBy: order[f.sortBy]);
                    },
                  ),
                  const SizedBox(width: 12),
                  ActionChip(
                    avatar: const Icon(Icons.tune, size: 18),
                    label: Text(f.isEmpty ? 'Filters' : 'Filters •'),
                    onPressed: () async {
                      final updated = await openTxnFilterSheet(context, f);
                      if (updated != null) _filter.value = updated;
                    },
                  ),
                  if (!f.isEmpty)
                    TextButton.icon(
                      onPressed: () => _filter.value = const TxnFilterState(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${list.length} result${list.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        net >= 0 ? Icons.trending_up : Icons.trending_down,
                        size: 16,
                        color: netColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _amount(
                          net,
                          withSign: true,
                          debit: net < 0,
                        ), // affichage signé
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: netColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Results
            Expanded(
              child: list.isEmpty
                  ? _EmptyState(
                      query: query,
                      onClear: () {
                        query = '';
                        _filter.value = const TxnFilterState();
                      },
                    )
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = list[i];
                        final isDebit = e.typeEntry == 'DEBIT';
                        final color = isDebit ? Colors.red : Colors.green;
                        final title = e.description ?? e.code ?? 'Transaction';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.12),
                            child: Icon(
                              isDebit ? Icons.south : Icons.north,
                              color: color,
                            ),
                          ),
                          title: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: _highlight(
                              title,
                              query,
                              theme.textTheme.bodyLarge!,
                              theme.textTheme.bodyLarge!.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          subtitle: Text(_formatWhen(e.dateTransaction)),
                          trailing: Text(
                            _amount(e.amount, debit: isDebit),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => close(context, e),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      tooltip: 'Filters',
      icon: const Icon(Icons.tune),
      onPressed: () async {
        final updated = await openTxnFilterSheet(context, _filter.value);
        if (updated != null) _filter.value = updated;
      },
    ),
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );
}

/// Empty state
class _EmptyState extends StatelessWidget {
  final String query;
  final VoidCallback onClear;
  const _EmptyState({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('No results', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              query.isEmpty
                  ? 'Try adjusting your filters.'
                  : 'No matches for “$query”.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh),
              label: const Text('Clear search & filters'),
            ),
          ],
        ),
      ),
    );
  }
}
