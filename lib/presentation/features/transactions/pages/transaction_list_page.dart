import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import '../../reports/report_page.dart';
import '../controllers/transaction_list_controller.dart';
import '../providers/transaction_list_providers.dart';
import '../utils/transaction_grouping.dart';
import '../widgets/day_header.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/transaction_summary_card.dart';

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
          TransactionSummaryCard(
            periodLabel: state.label,
            onPrev: () =>
                ref.read(transactionListStateProvider.notifier).prev(),
            onNext: () =>
                ref.read(transactionListStateProvider.notifier).next(),
            onTapPeriod: () => _openAnchorPicker(context, ref),
            expenseText: '-${exp ~/ 100}',
            incomeText: '+${inc ~/ 100}',
            netText: '${net >= 0 ? '+' : ''}${net ~/ 100}',
            netPositive: net >= 0,
            onOpenReport: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ReportPage()));
            },
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

  Future<void> _openAnchorPicker(BuildContext context, WidgetRef ref) async {
    final state = ref.read(transactionListStateProvider);
    DateTime temp = state.anchor;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return SafeArea(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  Text(
                    'Select date',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  CalendarDatePicker(
                    initialDate: state.anchor,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    onDateChanged: (d) => temp = d,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          ref
                              .read(transactionListStateProvider.notifier)
                              .resetToThisPeriod();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.today),
                        label: const Text('This period'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          ref
                              .read(transactionListStateProvider.notifier)
                              .setAnchor(temp);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
