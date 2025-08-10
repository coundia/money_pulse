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

  Future<List<TransactionEntry>> _load() async {
    final acc = await ref.read(accountRepoProvider).findDefault();
    if (acc == null) return const <TransactionEntry>[];
    return ref
        .read(transactionRepoProvider)
        .findByAccountForMonth(acc.id, month, typeEntry: _typeEntryString());
  }

  @override
  Widget build(BuildContext context) {
    // listen so a new add/edit/delete triggers rebuild
    ref.watch(transactionsProvider);

    final monthLabel = DateFormat.yMMMM().format(month);

    return FutureBuilder<List<TransactionEntry>>(
      future: _load(),
      builder: (context, snap) {
        final items = snap.data ?? const <TransactionEntry>[];
        final exp = items
            .where((e) => e.typeEntry == 'DEBIT')
            .fold<int>(0, (p, e) => p + e.amount);
        final inc = items
            .where((e) => e.typeEntry == 'CREDIT')
            .fold<int>(0, (p, e) => p + e.amount);
        final net = inc - exp;

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    // Month navigator + "This month" action
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
                              child: Text(
                                monthLabel,
                                key: ValueKey(monthLabel),
                                style: Theme.of(context).textTheme.titleMedium,
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
                    const SizedBox(height: 8),
                    // Filter UI: SegmentedButton with icons (no ChoiceChip)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SegmentedButton<TxnTypeFilter>(
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
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Summary texts (no borders, no pills)
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
            if (snap.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('No transactions for this month')),
              )
            else
              ...List.generate(items.length, (i) {
                final e = items[i];
                final isDebit = e.typeEntry == 'DEBIT';
                final sign = isDebit ? '-' : '+';
                final amount = (e.amount ~/ 100).toString();
                final date = DateFormat.yMMMd().format(e.dateTransaction);
                final color = isDebit ? Colors.red : Colors.green;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Dismissible(
                    key: ValueKey(e.id),
                    background: Container(color: Colors.red),
                    onDismissed: (_) async {
                      await ref.read(transactionRepoProvider).softDelete(e.id);
                      await ref.read(balanceProvider.notifier).load();
                      await ref.read(transactionsProvider.notifier).load();
                      setState(() {}); // reload month
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.12),
                        child: Icon(
                          isDebit ? Icons.south : Icons.north,
                          color: color,
                        ),
                      ),
                      title: Text(
                        e.description ?? e.code ?? 'Transaction',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(date),
                      trailing: Text(
                        '$sign$amount',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () async {
                        final ok = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => TransactionFormSheet(entry: e),
                        );
                        if (ok == true) {
                          await ref.read(balanceProvider.notifier).load();
                          await ref.read(transactionsProvider.notifier).load();
                          setState(() {}); // reload month
                        }
                      },
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
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
