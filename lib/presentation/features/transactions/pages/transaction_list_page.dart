import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import '../../reports/report_page.dart';
import '../../settings/settings_page.dart';
import '../controllers/transaction_list_controller.dart';
import '../providers/transaction_list_providers.dart';
import '../search/widgets/txn_search_cta.dart';
import '../transaction_quick_add_sheet.dart';
import '../utils/transaction_grouping.dart';
import '../widgets/day_header.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/transaction_summary_card.dart';
import '../search/txn_search_delegate.dart';

class TransactionListPage extends ConsumerWidget {
  const TransactionListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionListStateProvider);
    final itemsAsync = ref.watch(transactionListItemsProvider);

    return Scaffold(
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          final txns = items.cast<TransactionEntry>();
          final groups = groupByDay(txns);
          final exp = txns
              .where((e) => e.typeEntry == 'DEBIT')
              .fold<int>(0, (p, e) => p + e.amount);
          final inc = txns
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
              expenseCents: exp,
              incomeCents: inc,
              netCents: net,
              onOpenReport: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ReportPage()));
              },
              onOpenSettings: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
              onAddExpense: () => _onAdd(context, ref, 'DEBIT'),
              onAddIncome: () => _onAdd(context, ref, 'CREDIT'),
            ),

            const SizedBox(height: 8),
            if (txns.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text('Aucune transaction pour cette période'),
                ),
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
                      ref.invalidate(transactionListItemsProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction supprimée')),
                      );
                    },
                    onUpdated: () async {
                      await ref.read(balanceProvider.notifier).load();
                      await ref.read(transactionsProvider.notifier).load();
                      ref.invalidate(transactionListItemsProvider);
                    },
                    onSync: (entry) async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Synchronisation lancée')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
            TxnSearchCta(onTap: () => _openTxnSearch(context, txns)),
          ];

          return ListView(
            padding: const EdgeInsets.all(12),
            children: children,
          );
        },
      ),
    );
  }

  Future<void> _openTxnSearch(
    BuildContext context,
    List<TransactionEntry> items,
  ) async {
    final result = await showSearch<TransactionEntry?>(
      context: context,
      delegate: TxnSearchDelegate(items),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sélectionné: ${result.description ?? result.code ?? result.id}',
          ),
        ),
      );
    }
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
                    'Sélectionner la date',
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
                        label: const Text('Cette période'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          ref
                              .read(transactionListStateProvider.notifier)
                              .setAnchor(temp);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Appliquer'),
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

  Future<void> _onAdd(BuildContext context, WidgetRef ref, String type) async {
    final isDebit = type == 'DEBIT';
    final ok = await showRightDrawer<bool>(
      context,
      child: TransactionQuickAddSheet(initialIsDebit: isDebit),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (ok == true) {
      await ref.read(transactionsProvider.notifier).load();
      await ref.read(balanceProvider.notifier).load();
      ref.invalidate(transactionListItemsProvider);
    }
  }
}
