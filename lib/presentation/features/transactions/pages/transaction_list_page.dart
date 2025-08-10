import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import '../../reports/report_page.dart';
import '../controllers/transaction_list_controller.dart';
// removed: ../models/transaction_filters.dart
import '../providers/transaction_list_providers.dart';
import '../utils/transaction_grouping.dart';
import '../widgets/day_header.dart';
import '../widgets/transaction_tile.dart';

class TransactionListPage extends ConsumerWidget {
  const TransactionListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionListStateProvider);
    final itemsAsync = ref.watch(transactionListItemsProvider);

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) {
        final groups = groupByDay(items);
        final exp = items
            .where((e) => e.typeEntry == 'DEBIT')
            .fold<int>(0, (p, e) => p + e.amount);
        final inc = items
            .where((e) => e.typeEntry == 'CREDIT')
            .fold<int>(0, (p, e) => p + e.amount);
        final net = inc - exp;

        final children = <Widget>[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous',
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => ref
                            .read(transactionListStateProvider.notifier)
                            .prev(),
                      ),
                      Expanded(
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (c, a) =>
                                FadeTransition(opacity: a, child: c),
                            child: InkWell(
                              key: ValueKey(state.label),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: state.anchor,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  helpText: 'Select any day',
                                );
                                if (picked != null) {
                                  ref
                                      .read(
                                        transactionListStateProvider.notifier,
                                      )
                                      .setAnchor(picked);
                                }
                              },
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
                                      state.label,
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
                        tooltip: 'Next',
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => ref
                            .read(transactionListStateProvider.notifier)
                            .next(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => ref
                          .read(transactionListStateProvider.notifier)
                          .resetToThisPeriod(),
                      icon: const Icon(Icons.today),
                      label: const Text('This period'),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                      IconButton(
                        tooltip: 'Report',
                        icon: const Icon(Icons.pie_chart),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReportPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('No transactions for this period')),
            )
          else ...[
            for (final g in groups) ...[
              DayHeader(group: g),
              ...g.items.map(
                (e) => TransactionTile(
                  entry: e,
                  onDeleted: () async {
                    await ref.read(transactionRepoProvider).softDelete(e.id);
                    await ref.read(balanceProvider.notifier).load();
                    await ref.read(transactionsProvider.notifier).load();
                  },
                  onUpdated: () async {
                    await ref.read(balanceProvider.notifier).load();
                    await ref.read(transactionsProvider.notifier).load();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ];

        return ListView(padding: const EdgeInsets.all(12), children: children);
      },
    );
  }

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
