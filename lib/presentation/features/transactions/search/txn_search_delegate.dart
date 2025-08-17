// Minimalist search delegate (FR): no inline buttons, single "options" sheet + keyboard hide; defocus on open; clean header summary.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Champ en français, style compact
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
    if (sameDay) return 'Jour: ${_formatWhen(from!)}';
    if (from != null && to != null) {
      return 'Période: ${_formatWhen(from)} → ${_formatWhen(to)}';
    }
    if (from != null) return 'À partir du ${_formatWhen(from)}';
    return 'Jusqu’au ${_formatWhen(to!)}';
  }

  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _ensureUnfocused() {
    if (_didUnfocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _hideKeyboard());
    _didUnfocus = true;
  }

  Future<void> _openOptionsSheet(BuildContext context) async {
    _hideKeyboard();
    final theme = Theme.of(context);
    final f = _filter.value;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        TxnTypeFilter type = f.type;
        TxnSortBy sortBy = f.sortBy;

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Options', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Masquer le clavier',
                    onPressed: () {
                      _hideKeyboard();
                      Navigator.of(ctx).maybePop();
                    },
                    icon: const Icon(Icons.keyboard_hide),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Type
              const SizedBox(height: 12),

              // Périodes rapides
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Période', style: theme.textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.today),
                    label: const Text('Aujourd’hui'),
                    onPressed: () {
                      final d = _strip(DateTime.now());
                      _filter.value = f.copyWith(
                        from: d,
                        to: d,
                        type: type,
                        sortBy: sortBy,
                      );
                      Navigator.of(ctx).pop();
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_view_month),
                    label: const Text('Ce mois-ci'),
                    onPressed: () {
                      final (from, to) = _thisMonthRange();
                      _filter.value = f.copyWith(
                        from: from,
                        to: to,
                        type: type,
                        sortBy: sortBy,
                      );
                      Navigator.of(ctx).pop();
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Cette année'),
                    onPressed: () {
                      final (from, to) = _thisYearRange();
                      _filter.value = f.copyWith(
                        from: from,
                        to: to,
                        type: type,
                        sortBy: sortBy,
                      );
                      Navigator.of(ctx).pop();
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.tune),
                    label: const Text('Filtres avancés…'),
                    onPressed: () async {
                      final updated = await openTxnFilterSheet(
                        context,
                        _filter.value,
                      );
                      if (updated != null) _filter.value = updated;
                      if (context.mounted) Navigator.of(ctx).maybePop();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Tri
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Trier par', style: theme.textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              SegmentedButton<TxnSortBy>(
                segments: const [
                  ButtonSegment(
                    value: TxnSortBy.dateDesc,
                    label: Text('Date ↓'),
                  ),
                  ButtonSegment(
                    value: TxnSortBy.dateAsc,
                    label: Text('Date ↑'),
                  ),
                  ButtonSegment(
                    value: TxnSortBy.amountDesc,
                    label: Text('Montant ↓'),
                  ),
                  ButtonSegment(
                    value: TxnSortBy.amountAsc,
                    label: Text('Montant ↑'),
                  ),
                ],
                selected: {sortBy},
                showSelectedIcon: false,
                onSelectionChanged: (s) => sortBy = s.first,
              ),

              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      _filter.value = const TxnFilterState();
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réinitialiser'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      _filter.value = f.copyWith(type: type, sortBy: sortBy);
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Appliquer'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
            // En-tête ultra-minimal (texte seulement)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _rangeLabel(f),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        semanticLabel: net >= 0
                            ? 'Solde positif'
                            : 'Solde négatif',
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
            ),
            const Divider(height: 1),

            // Liste
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

  // AppBar actions ultra-minimales: masquer clavier + options
  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      tooltip: 'Masquer le clavier',
      icon: const Icon(Icons.keyboard_hide),
      onPressed: _hideKeyboard,
    ),
    IconButton(
      tooltip: 'Afficher les options',
      icon: const Icon(Icons.more_horiz),
      onPressed: () => _openOptionsSheet(context),
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
