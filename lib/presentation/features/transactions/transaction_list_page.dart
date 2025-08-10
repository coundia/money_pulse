import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_form_sheet.dart';

class TransactionListPage extends ConsumerStatefulWidget {
  const TransactionListPage({super.key});

  @override
  ConsumerState<TransactionListPage> createState() =>
      _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? typeFilter; // null = All, 'DEBIT' = Expense, 'CREDIT' = Income

  DateTime _nextMonth(DateTime d) => DateTime(d.year, d.month + 1, 1);
  DateTime _prevMonth(DateTime d) => DateTime(d.year, d.month - 1, 1);

  Future<List<TransactionEntry>> _load() async {
    final acc = await ref.read(accountRepoProvider).findDefault();
    if (acc == null) return const <TransactionEntry>[];
    return ref
        .read(transactionRepoProvider)
        .findByAccountForMonth(acc.id, month, typeEntry: typeFilter);
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  children: [
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
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: typeFilter == null,
                          onSelected: (_) => setState(() => typeFilter = null),
                        ),
                        ChoiceChip(
                          label: const Text('Expense'),
                          selected: typeFilter == 'DEBIT',
                          onSelected: (_) =>
                              setState(() => typeFilter = 'DEBIT'),
                        ),
                        ChoiceChip(
                          label: const Text('Income'),
                          selected: typeFilter == 'CREDIT',
                          onSelected: (_) =>
                              setState(() => typeFilter = 'CREDIT'),
                        ),
                        TextButton.icon(
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
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _pill(context, 'Expense', '-${exp ~/ 100}', Colors.red),
                        _pill(
                          context,
                          'Income',
                          '+${inc ~/ 100}',
                          Colors.green,
                        ),
                        _pill(
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

  Widget _pill(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
