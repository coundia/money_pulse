import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_form_sheet.dart';

enum TxnTypeFilter { all, expense, income }

class TransactionListPage extends ConsumerStatefulWidget {
  const TransactionListPage({super.key});

  @override
  ConsumerState<TransactionListPage> createState() =>
      _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  TxnTypeFilter typeFilter = TxnTypeFilter.all;

  DateTime _nextMonth(DateTime d) => DateTime(d.year, d.month + 1, 1);
  DateTime _prevMonth(DateTime d) => DateTime(d.year, d.month - 1, 1);

  String? _typeEntryString() {
    switch (typeFilter) {
      case TxnTypeFilter.expense:
        return 'DEBIT';
      case TxnTypeFilter.income:
        return 'CREDIT';
      case TxnTypeFilter.all:
        return null;
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select any day in the month',
    );
    if (picked != null) {
      setState(() => month = DateTime(picked.year, picked.month, 1));
    }
  }

  Future<List<TransactionEntry>> _load() async {
    final acc = await ref.read(accountRepoProvider).findDefault();
    if (acc == null) return const <TransactionEntry>[];
    return ref
        .read(transactionRepoProvider)
        .findByAccountForMonth(acc.id, month, typeEntry: _typeEntryString());
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when txs change
    ref.watch(transactionsProvider);

    final monthLabel = DateFormat.yMMMM().format(month);

    return FutureBuilder<List<TransactionEntry>>(
      future: _load(),
      builder: (context, snap) {
        final items = snap.data ?? const <TransactionEntry>[];
        final groups = _groupByDay(items);

        final exp = items
            .where((e) => e.typeEntry == 'DEBIT')
            .fold<int>(0, (p, e) => p + e.amount);
        final inc = items
            .where((e) => e.typeEntry == 'CREDIT')
            .fold<int>(0, (p, e) => p + e.amount);
        final net = inc - exp;

        final children = <Widget>[
          // Top header (month + filters + totals)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                children: [
                  // Month navigator with tappable title (opens month picker)
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () =>
                            setState(() => month = _prevMonth(month)),
                      ),
                      Expanded(
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (c, a) =>
                                FadeTransition(opacity: a, child: c),
                            child: InkWell(
                              key: ValueKey(monthLabel),
                              onTap: _pickMonth,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_month, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      monthLabel,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () =>
                            setState(() => month = _nextMonth(month)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        month = DateTime(
                          DateTime.now().year,
                          DateTime.now().month,
                          1,
                        );
                      }),
                      icon: const Icon(Icons.today),
                      label: const Text('This month'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Filter UI
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SegmentedButton<TxnTypeFilter>(
                      segments: const [
                        ButtonSegment(
                          value: TxnTypeFilter.all,
                          icon: Icon(Icons.all_inclusive),
                          label: Text('All'),
                        ),
                        ButtonSegment(
                          value: TxnTypeFilter.expense,
                          icon: Icon(Icons.south),
                          label: Text('Expense'),
                        ),
                        ButtonSegment(
                          value: TxnTypeFilter.income,
                          icon: Icon(Icons.north),
                          label: Text('Income'),
                        ),
                      ],
                      selected: {typeFilter},
                      onSelectionChanged: (s) =>
                          setState(() => typeFilter = s.first),
                      showSelectedIcon: false,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Summary texts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _summaryText(
                        context,
                        'Expense',
                        '-${exp ~/ 100}',
                        Colors.red,
                      ),
                      _summaryText(
                        context,
                        'Income',
                        '+${inc ~/ 100}',
                        Colors.green,
                      ),
                      _summaryText(
                        context,
                        'Net',
                        '${net >= 0 ? '+' : ''}${net ~/ 100}',
                        net >= 0 ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ];

        if (snap.connectionState == ConnectionState.waiting) {
          children.add(
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (items.isEmpty) {
          children.add(
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('No transactions for this month')),
            ),
          );
        } else {
          for (final g in groups) {
            // Section header
            children.add(_DayHeader(group: g));
            // Items of the day
            children.addAll(
              g.items.map(
                (e) => _TransactionTile(
                  entry: e,
                  onDeleted: () async {
                    await ref.read(transactionRepoProvider).softDelete(e.id);
                    await ref.read(balanceProvider.notifier).load();
                    await ref.read(transactionsProvider.notifier).load();
                    setState(() {}); // reload month
                  },
                  onUpdated: () async {
                    await ref.read(balanceProvider.notifier).load();
                    await ref.read(transactionsProvider.notifier).load();
                    setState(() {}); // reload month
                  },
                ),
              ),
            );
            children.add(const SizedBox(height: 8));
          }
        }

        return ListView(padding: const EdgeInsets.all(12), children: children);
      },
    );
  }

  // Group transactions by local day, newest day first
  List<_DayGroup> _groupByDay(List<TransactionEntry> items) {
    final map = <DateTime, List<TransactionEntry>>{};
    for (final e in items) {
      final d = DateTime(
        e.dateTransaction.year,
        e.dateTransaction.month,
        e.dateTransaction.day,
      );
      map.putIfAbsent(d, () => []).add(e);
    }
    final days = map.keys.toList()..sort((a, b) => b.compareTo(a)); // desc
    return days.map((d) {
      final dayItems = map[d]!
        ..sort((a, b) => b.dateTransaction.compareTo(a.dateTransaction));
      final expense = dayItems
          .where((e) => e.typeEntry == 'DEBIT')
          .fold<int>(0, (p, e) => p + e.amount);
      final income = dayItems
          .where((e) => e.typeEntry == 'CREDIT')
          .fold<int>(0, (p, e) => p + e.amount);
      return _DayGroup(
        day: d,
        items: dayItems,
        expense: expense,
        income: income,
      );
    }).toList();
  }

  // Simple text-only summary (no borders, no background)
  Widget _summaryText(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DayGroup {
  final DateTime day;
  final List<TransactionEntry> items;
  final int expense;
  final int income;
  const _DayGroup({
    required this.day,
    required this.items,
    required this.expense,
    required this.income,
  });

  int get net => income - expense;
}

class _DayHeader extends StatelessWidget {
  final _DayGroup group;
  const _DayHeader({required this.group});

  String _friendly(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dd = DateTime(d.year, d.month, d.day);
    if (dd == today) return 'Today';
    if (dd == yesterday) return 'Yesterday';
    return DateFormat.EEEE().addPattern(', ').add_MMMd().format(d);
  }

  @override
  Widget build(BuildContext context) {
    final net = group.net;
    final netColor = net >= 0 ? Colors.green : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        children: [
          Text(
            _friendly(group.day),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          Row(
            children: [
              const SizedBox(width: 10),
              Text(
                '${net >= 0 ? '+' : ''}${net ~/ 100}',
                style: TextStyle(color: netColor, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionEntry entry;
  final Future<void> Function() onDeleted;
  final Future<void> Function() onUpdated;

  const _TransactionTile({
    required this.entry,
    required this.onDeleted,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final isDebit = entry.typeEntry == 'DEBIT';
    final sign = isDebit ? '-' : '+';
    final amount = (entry.amount ~/ 100).toString();
    final date = DateFormat.Hm().format(entry.dateTransaction);
    final color = isDebit ? Colors.red : Colors.green;

    return Dismissible(
      key: ValueKey(entry.id),
      background: Container(color: Colors.red),
      onDismissed: (_) async => onDeleted(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(isDebit ? Icons.south : Icons.north, color: color),
        ),
        title: Text(
          entry.description ?? entry.code ?? 'Transaction',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(date),
        trailing: Text(
          '$sign$amount',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        onTap: () async {
          final ok = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => TransactionFormSheet(entry: entry),
          );
          if (ok == true) {
            await onUpdated();
          }
        },
      ),
    );
  }
}
