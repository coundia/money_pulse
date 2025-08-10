import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/account_selection.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/features/settings/settings_page.dart';
import '../../reports/report_page.dart';
import '../controllers/transaction_list_controller.dart';
import '../models/transaction_filters.dart';
import '../providers/transaction_list_providers.dart';
import '../transaction_form_sheet.dart';
import '../utils/transaction_grouping.dart';
import '../widgets/day_header.dart';
import '../widgets/transaction_tile.dart';
import '../search/txn_search_delegate.dart';

class TransactionListPage extends ConsumerWidget {
  const TransactionListPage({super.key});

  Future<Account?> _resolveAccount(WidgetRef ref) {
    return ref.read(selectedAccountProvider.future);
  }

  Future<void> _showAccountPicker(BuildContext context, WidgetRef ref) async {
    final accounts = await ref.read(accountRepoProvider).findAllActive();
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<Account>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(8),
          itemBuilder: (c, i) {
            final a = accounts[i];
            return ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: Text(a.code ?? ''),
              subtitle: Text(a.description ?? ''),
              trailing: (ref.read(selectedAccountIdProvider) ?? '') == a.id
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(c, a),
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: accounts.length,
        ),
      ),
    );
    if (picked != null) {
      ref.read(selectedAccountIdProvider.notifier).state = picked.id;
      await ref.read(balanceProvider.notifier).load();
      await ref.read(transactionsProvider.notifier).load();
    }
  }

  Future<void> _showShareDialog(BuildContext context, Account acc) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Share account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Code: ${acc.code}'),
            const SizedBox(height: 6),
            SelectableText('ID: ${acc.id}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: 'Account ${acc.code} (${acc.id})'),
              );
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              }
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPeriodSheet(BuildContext context, WidgetRef ref) async {
    final current = ref.read(transactionListStateProvider);
    final sel = await showModalBottomSheet<Period>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text(
              'View period',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.view_week),
              title: const Text('Weekly'),
              onTap: () => Navigator.pop(context, Period.weekly),
              trailing: current.period == Period.weekly
                  ? const Icon(Icons.check)
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Monthly'),
              onTap: () => Navigator.pop(context, Period.monthly),
              trailing: current.period == Period.monthly
                  ? const Icon(Icons.check)
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Yearly'),
              onTap: () => Navigator.pop(context, Period.yearly),
              trailing: current.period == Period.yearly
                  ? const Icon(Icons.check)
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (sel != null) {
      ref.read(transactionListStateProvider.notifier).setPeriod(sel);
    }
  }

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

                      PopupMenuButton<_MenuAction>(
                        tooltip: 'More',
                        onSelected: (_MenuAction action) async {
                          switch (action) {
                            case _MenuAction.search:
                              final result =
                                  await showSearch<TransactionEntry?>(
                                    context: context,
                                    delegate: TxnSearchDelegate(items),
                                  );
                              if (result != null) {
                                final ok = await showModalBottomSheet<bool>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) =>
                                      TransactionFormSheet(entry: result),
                                );
                                if (ok == true) {
                                  await ref
                                      .read(balanceProvider.notifier)
                                      .load();
                                  await ref
                                      .read(transactionsProvider.notifier)
                                      .load();
                                }
                              }
                              break;
                            case _MenuAction.period:
                              await _showPeriodSheet(context, ref);
                              break;
                            case _MenuAction.changeAccount:
                              await _showAccountPicker(context, ref);
                              break;
                            case _MenuAction.sync:
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sync started… (demo)'),
                                  ),
                                );
                                await Future.delayed(
                                  const Duration(milliseconds: 800),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sync complete'),
                                    ),
                                  );
                                }
                              }
                              break;
                            case _MenuAction.share:
                              final acc = await _resolveAccount(ref);
                              if (!context.mounted || acc == null) break;
                              await _showShareDialog(context, acc);
                              break;
                            case _MenuAction.settings:
                              if (!context.mounted) break;
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsPage(),
                                ),
                              );
                              break;
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _MenuAction.search,
                            child: ListTile(
                              leading: Icon(Icons.search),
                              title: Text('Search'),
                            ),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(
                            value: _MenuAction.period,
                            child: ListTile(
                              leading: Icon(Icons.filter_alt),
                              title: Text('Select period'),
                            ),
                          ),
                          PopupMenuItem(
                            value: _MenuAction.changeAccount,
                            child: ListTile(
                              leading: Icon(Icons.account_balance_wallet),
                              title: Text('Change account'),
                            ),
                          ),
                          PopupMenuItem(
                            value: _MenuAction.sync,
                            child: ListTile(
                              leading: Icon(Icons.sync),
                              title: Text('Sync transactions'),
                            ),
                          ),
                          PopupMenuItem(
                            value: _MenuAction.share,
                            child: ListTile(
                              leading: Icon(Icons.ios_share),
                              title: Text('Share account'),
                            ),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(
                            value: _MenuAction.settings,
                            child: ListTile(
                              leading: Icon(Icons.settings),
                              title: Text('Settings'),
                            ),
                          ),
                        ],
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
                  const SizedBox(height: 4),
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
                      selected: {state.typeFilter},
                      onSelectionChanged: (s) => ref
                          .read(transactionListStateProvider.notifier)
                          .setTypeFilter(s.first),
                      showSelectedIcon: false,
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

enum _MenuAction { search, period, changeAccount, sync, share, settings }
