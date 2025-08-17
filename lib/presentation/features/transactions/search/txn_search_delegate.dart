// Search delegate with compact, French UI; rounded filled search field; no auto-focus; segmented type filter; overflow menu; range chip; net summary.

import 'package:flutter/material.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import '../widgets/transaction_detail_view.dart';
import 'models/txn_search_filters.dart';
import 'widgets/txn_filter_sheet.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

class TxnSearchDelegate extends SearchDelegate<TransactionEntry?> {
  final List<TransactionEntry> items;
  final ValueNotifier<TxnFilterState> _filter;
  bool _didUnfocus = false;

  TxnSearchDelegate(this.items)
    : _filter = ValueNotifier<TxnFilterState>(_todayFilter());

  // ---- French placeholder & compact look for the search input
  @override
  String get searchFieldLabel => 'Rechercher des transactions';

  @override
  TextStyle? get searchFieldStyle => const TextStyle(fontSize: 16);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final hintColor = theme.colorScheme.onSurfaceVariant;
    return theme.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant.withOpacity(.6),
        hintStyle: TextStyle(color: hintColor),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
      ),
      textTheme: theme.textTheme,
      appBarTheme: theme.appBarTheme,
    );
  }

  static DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  static TxnFilterState _todayFilter() {
    final d = _strip(DateTime.now());
    return TxnFilterState(from: d, to: d);
  }

  static (DateTime from, DateTime to) _thisMonthRange() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 0);
    return (from, to);
  }

  static (DateTime from, DateTime to) _thisYearRange() {
    final now = DateTime.now();
    final from = DateTime(now.year, 1, 1);
    final to = DateTime(now.year, 12, 31);
    return (from, to);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isTodayRange(TxnFilterState f) {
    if (f.from == null || f.to == null) return false;
    final t = _strip(DateTime.now());
    return _isSameDay(f.from!, t) && _isSameDay(f.to!, t);
  }

  bool _isThisMonthRange(TxnFilterState f) {
    if (f.from == null || f.to == null) return false;
    final (mFrom, mTo) = _thisMonthRange();
    return _isSameDay(f.from!, mFrom) && _isSameDay(f.to!, mTo);
  }

  bool _isThisYearRange(TxnFilterState f) {
    if (f.from == null || f.to == null) return false;
    final (yFrom, yTo) = _thisYearRange();
    return _isSameDay(f.from!, yFrom) && _isSameDay(f.to!, yTo);
  }

  bool _isExpenseType(String t) {
    final x = t.toUpperCase();
    return x == 'DEBIT' || x == 'PRÊT' || x == 'PRET' || x == 'LOAN';
  }

  bool _isIncomeType(String t) {
    final x = t.toUpperCase();
    return x == 'CREDIT' || x == 'REMBOURSEMENT' || x == 'REPAYMENT';
  }

  bool _isDebtType(String t) {
    final x = t.toUpperCase();
    return x == 'DEBT' || x == 'DETTE';
  }

  bool _isLoanType(String t) {
    final x = t.toUpperCase();
    return x == 'PRÊT' || x == 'PRET' || x == 'LOAN';
  }

  bool _isReimbursementType(String t) {
    final x = t.toUpperCase();
    return x == 'REMBOURSEMENT' || x == 'REPAYMENT';
  }

  List<TransactionEntry> _applyFilters(String q, TxnFilterState f) {
    final query = q.trim().toLowerCase();
    Iterable<TransactionEntry> it = items;

    switch (f.type) {
      case TxnTypeFilter.expense:
        it = it.where((e) => _isExpenseType(e.typeEntry));
        break;
      case TxnTypeFilter.income:
        it = it.where((e) => _isIncomeType(e.typeEntry));
        break;
      case TxnTypeFilter.debt:
        it = it.where((e) => _isDebtType(e.typeEntry));
        break;
      case TxnTypeFilter.loan:
        it = it.where((e) => _isLoanType(e.typeEntry));
        break;
      case TxnTypeFilter.reimbursement:
        it = it.where((e) => _isReimbursementType(e.typeEntry));
        break;
      case TxnTypeFilter.all:
        break;
    }

    if (f.from != null) {
      final start = DateTime(f.from!.year, f.from!.month, f.from!.day);
      it = it.where((e) => !e.dateTransaction.isBefore(start));
    }
    if (f.to != null) {
      final end = DateTime(f.to!.year, f.to!.month, f.to!.day, 23, 59, 59, 999);
      it = it.where((e) => !e.dateTransaction.isAfter(end));
    }

    if (f.minCents != null) it = it.where((e) => e.amount >= f.minCents!);
    if (f.maxCents != null) it = it.where((e) => e.amount <= f.maxCents!);

    if (query.isNotEmpty) {
      it = it.where((e) {
        final text = '${e.description ?? ''} ${e.code ?? ''}  '.toLowerCase();
        return text.contains(query);
      });
    }

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

  int _computeNetCents(String q, TxnFilterState f) {
    final base = _applyFilters(q, f.copyWith(type: TxnTypeFilter.all));
    int net = 0;
    for (final e in base) {
      final t = e.typeEntry;
      if (_isIncomeType(t)) net += e.amount;
      if (_isExpenseType(t)) net -= e.amount;
    }
    return net;
  }

  String _formatWhen(DateTime d) => Formatters.dateFull(d);

  String _amount(int cents, {required bool debit}) =>
      Formatters.amountFromCents(cents);

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

  String _rangeLabel(TxnFilterState f) {
    final from = f.from, to = f.to;
    if (from == null && to == null) return 'Toutes dates';
    final sameDay = (from != null && to != null)
        ? (from.year == to.year && from.month == to.month && from.day == to.day)
        : false;
    if (sameDay) {
      final isToday = _isSameDay(from!, _strip(DateTime.now()));
      return isToday ? 'Aujourd’hui' : Formatters.dateFull(from);
    }
    if (from != null && to != null) {
      final sameYear = from.year == to.year;
      final left = '${from.day} ${DateFormatters._monthShort(from.month)}';
      final right = '${to.day} ${DateFormatters._monthShort(to.month)}';
      return sameYear
          ? 'Du $left au $right ${from.year}'
          : 'Du $left ${from.year} au $right ${to.year}';
    }
    if (from != null) return 'À partir du ${Formatters.dateFull(from)}';
    return 'Jusqu’au ${Formatters.dateFull(to!)}';
  }

  void _ensureUnfocused() {
    if (_didUnfocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
    _didUnfocus = true;
  }

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    _ensureUnfocused();
    final theme = Theme.of(context);
    return ValueListenableBuilder<TxnFilterState>(
      valueListenable: _filter,
      builder: (context, f, _) {
        final list = _applyFilters(query, f);
        final net = _computeNetCents(query, f);
        final netColor = net >= 0 ? Colors.green : Colors.red;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<TxnTypeFilter>(
                          segments: const [
                            ButtonSegment(
                              value: TxnTypeFilter.all,
                              label: Text('Tous'),
                              icon: Icon(Icons.all_inclusive),
                            ),
                            ButtonSegment(
                              value: TxnTypeFilter.expense,
                              label: Text('Dépenses'),
                              icon: Icon(Icons.south),
                            ),
                            ButtonSegment(
                              value: TxnTypeFilter.income,
                              label: Text('Revenus'),
                              icon: Icon(Icons.north),
                            ),
                          ],
                          selected: {
                            f.type == TxnTypeFilter.debt ||
                                    f.type == TxnTypeFilter.loan ||
                                    f.type == TxnTypeFilter.reimbursement
                                ? TxnTypeFilter.all
                                : f.type,
                          },
                          onSelectionChanged: (set) {
                            FocusManager.instance.primaryFocus?.unfocus();
                            final sel = set.first;
                            _filter.value = f.copyWith(type: sel);
                          },
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('Filtres…'),
                        onPressed: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final updated = await openTxnFilterSheet(
                            context,
                            _filter.value,
                          );
                          if (updated != null) _filter.value = updated;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.calendar_month, size: 18),
                        label: Text(_rangeLabel(f)),
                        onPressed: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: f.from ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            final d = _strip(picked);
                            _filter.value = f.copyWith(from: d, to: d);
                          }
                        },
                      ),
                      FilterChip(
                        label: Text(switch (f.sortBy) {
                          TxnSortBy.dateDesc => 'Date ↓',
                          TxnSortBy.dateAsc => 'Date ↑',
                          TxnSortBy.amountDesc => 'Montant ↓',
                          TxnSortBy.amountAsc => 'Montant ↑',
                        }),
                        selected: true,
                        onSelected: (_) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final order = {
                            TxnSortBy.dateDesc: TxnSortBy.dateAsc,
                            TxnSortBy.dateAsc: TxnSortBy.amountDesc,
                            TxnSortBy.amountDesc: TxnSortBy.amountAsc,
                            TxnSortBy.amountAsc: TxnSortBy.dateDesc,
                          };
                          _filter.value = f.copyWith(sortBy: order[f.sortBy]);
                        },
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${list.length} résultat${list.length > 1 ? 's' : ''}',
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
                            _amount(net, debit: net < 0),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: netColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: list.isEmpty
                  ? _EmptyState(
                      query: query,
                      onClear: () {
                        query = '';
                        _filter.value = _todayFilter();
                      },
                    )
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = list[i];
                        final isDebit = _isExpenseType(e.typeEntry);
                        final color = isDebit ? Colors.red : Colors.green;
                        final title =
                            (e.description?.trim().isNotEmpty ?? false)
                            ? e.description!.trim()
                            : 'Transaction';

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
                          onTap: () async {
                            await showRightDrawer<void>(
                              context,
                              child: TransactionDetailView(entry: e),
                              widthFraction: 0.92,
                              heightFraction: 0.96,
                            );
                          },
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
    PopupMenuButton<int>(
      tooltip: 'Options',
      icon: const Icon(Icons.more_vert),
      onSelected: (v) async {
        final f = _filter.value;
        FocusManager.instance.primaryFocus?.unfocus();
        if (v == 1) {
          final updated = await openTxnFilterSheet(context, f);
          if (updated != null) _filter.value = updated;
        } else if (v == 2) {
          final d = _strip(DateTime.now());
          _filter.value = f.copyWith(from: d, to: d);
        } else if (v == 3) {
          final (from, to) = _thisMonthRange();
          _filter.value = f.copyWith(from: from, to: to);
        } else if (v == 4) {
          final (from, to) = _thisYearRange();
          _filter.value = f.copyWith(from: from, to: to);
        } else if (v == 5) {
          query = '';
        } else if (v == 6) {
          query = '';
          _filter.value = _todayFilter();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 1, child: Text('Filtres…')),
        const PopupMenuItem(value: 2, child: Text('Aujourd’hui')),
        const PopupMenuItem(value: 3, child: Text('Ce mois-ci')),
        const PopupMenuItem(value: 4, child: Text('Cette année')),
        if (query.isNotEmpty)
          const PopupMenuItem(value: 5, child: Text('Effacer la recherche')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 6, child: Text('Réinitialiser')),
      ],
    ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );
}

class _EmptyState extends StatelessWidget {
  final String query;
  final VoidCallback onClear;
  const _EmptyState({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = query.isEmpty
        ? 'Ajustez vos filtres.'
        : 'Aucune correspondance pour « $query ».';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('Aucun résultat', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh),
              label: const Text('Réinitialiser la recherche et les filtres'),
            ),
          ],
        ),
      ),
    );
  }
}

class DateFormatters {
  static const _months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  static String _monthShort(int m) => _months[(m - 1).clamp(0, 11)];
}
