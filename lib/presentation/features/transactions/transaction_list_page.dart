import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/account_selection.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_form_sheet.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/presentation/features/settings/settings_page.dart';

enum TxnTypeFilter { all, expense, income }

enum Period { weekly, monthly, yearly }

enum _MenuAction { search, period, changeAccount, sync, share, settings }

class TransactionListPage extends ConsumerStatefulWidget {
  const TransactionListPage({super.key});

  @override
  ConsumerState<TransactionListPage> createState() =>
      _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  Period period = Period.monthly;
  DateTime anchor = DateTime(DateTime.now().year, DateTime.now().month, 1);
  TxnTypeFilter typeFilter = TxnTypeFilter.all;

  DateTime _startOfWeek(DateTime d) {
    final wd = d.weekday;
    final first = d.subtract(Duration(days: wd - 1));
    return DateTime(first.year, first.month, first.day);
  }

  (DateTime from, DateTime to, String label) _rangeLabel() {
    switch (period) {
      case Period.weekly:
        final start = _startOfWeek(anchor);
        final end = start.add(const Duration(days: 7));
        final label =
            '${DateFormat.MMMd().format(start)} – ${DateFormat.MMMd().format(end.subtract(const Duration(days: 1)))}';
        return (start, end, label);
      case Period.monthly:
        final start = DateTime(anchor.year, anchor.month, 1);
        final end = DateTime(anchor.year, anchor.month + 1, 1);
        final label = DateFormat.yMMMM().format(start);
        return (start, end, label);
      case Period.yearly:
        final start = DateTime(anchor.year, 1, 1);
        final end = DateTime(anchor.year + 1, 1, 1);
        final label = DateFormat.y().format(start);
        return (start, end, label);
    }
  }

  void _prev() {
    setState(() {
      switch (period) {
        case Period.weekly:
          anchor = anchor.subtract(const Duration(days: 7));
          break;
        case Period.monthly:
          anchor = DateTime(anchor.year, anchor.month - 1, 1);
          break;
        case Period.yearly:
          anchor = DateTime(anchor.year - 1, 1, 1);
          break;
      }
    });
  }

  void _next() {
    setState(() {
      switch (period) {
        case Period.weekly:
          anchor = anchor.add(const Duration(days: 7));
          break;
        case Period.monthly:
          anchor = DateTime(anchor.year, anchor.month + 1, 1);
          break;
        case Period.yearly:
          anchor = DateTime(anchor.year + 1, 1, 1);
          break;
      }
    });
  }

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
      initialDate: anchor,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select any day',
    );
    if (picked != null) {
      setState(() => anchor = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<Account?> _resolveAccount() {
    // Use shared selection provider so HomePage AppBar updates too.
    return ref.read(selectedAccountProvider.future);
  }

  Future<List<TransactionEntry>> _load() async {
    final acc = await _resolveAccount();
    if (acc == null) return const <TransactionEntry>[];
    final (from, to, _) = _rangeLabel();
    return ref
        .read(transactionRepoProvider)
        .findByAccountBetween(acc.id, from, to, typeEntry: _typeEntryString());
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when txs or current account changes
    ref.watch(transactionsProvider);
    ref.watch(selectedAccountProvider);

    final (from, to, periodLabel) = _rangeLabel();

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
                        onPressed: _prev,
                      ),
                      Expanded(
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (c, a) =>
                                FadeTransition(opacity: a, child: c),
                            child: InkWell(
                              key: ValueKey(periodLabel),
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
                                      periodLabel,
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
                        onPressed: _next,
                      ),
                      PopupMenuButton<_MenuAction>(
                        tooltip: 'More',
                        onSelected: (_MenuAction action) async {
                          switch (action) {
                            case _MenuAction.search:
                              final result =
                                  await showSearch<TransactionEntry?>(
                                    context: context,
                                    delegate: _TxnSearchDelegate(items),
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
                                  setState(() {});
                                }
                              }
                              break;
                            case _MenuAction.period:
                              _showPeriodSheet();
                              break;
                            case _MenuAction.changeAccount:
                              _showAccountPicker();
                              break;
                            case _MenuAction.sync:
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sync started… (demo)'),
                                  ),
                                );
                                await Future.delayed(
                                  const Duration(milliseconds: 800),
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sync complete'),
                                    ),
                                  );
                                }
                              }
                              break;
                            case _MenuAction.share:
                              final acc = await _resolveAccount();
                              if (!mounted || acc == null) break;
                              await _showShareDialog(acc);
                              break;
                            case _MenuAction.settings:
                              if (!mounted) break;
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsPage(),
                                ),
                              );
                              setState(() {});
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
                      onPressed: () => setState(() {
                        switch (period) {
                          case Period.weekly:
                            anchor = _startOfWeek(DateTime.now());
                            break;
                          case Period.monthly:
                            anchor = DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              1,
                            );
                            break;
                          case Period.yearly:
                            anchor = DateTime(DateTime.now().year, 1, 1);
                            break;
                        }
                      }),
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
                      selected: {typeFilter},
                      onSelectionChanged: (s) =>
                          setState(() => typeFilter = s.first),
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
                        '-${(items.where((e) => e.typeEntry == 'DEBIT').fold<int>(0, (p, e) => p + e.amount)) ~/ 100}',
                        Colors.red,
                      ),
                      _summaryText(
                        context,
                        'Income',
                        '+${(items.where((e) => e.typeEntry == 'CREDIT').fold<int>(0, (p, e) => p + e.amount)) ~/ 100}',
                        Colors.green,
                      ),
                      _summaryText(
                        context,
                        'Net',
                        '${(((items.where((e) => e.typeEntry == 'CREDIT').fold<int>(0, (p, e) => p + e.amount)) - (items.where((e) => e.typeEntry == 'DEBIT').fold<int>(0, (p, e) => p + e.amount)))) >= 0 ? '+' : ''}${(((items.where((e) => e.typeEntry == 'CREDIT').fold<int>(0, (p, e) => p + e.amount)) - (items.where((e) => e.typeEntry == 'DEBIT').fold<int>(0, (p, e) => p + e.amount)))) ~/ 100}',
                        (((items
                                        .where((e) => e.typeEntry == 'CREDIT')
                                        .fold<int>(0, (p, e) => p + e.amount)) -
                                    (items
                                        .where((e) => e.typeEntry == 'DEBIT')
                                        .fold<int>(
                                          0,
                                          (p, e) => p + e.amount,
                                        )))) >=
                                0
                            ? Colors.green
                            : Colors.red,
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
              child: Center(child: Text('No transactions for this period')),
            ),
          );
        } else {
          for (final g in groups) {
            children.add(_DayHeader(group: g));
            children.addAll(
              g.items.map(
                (e) => _TransactionTile(
                  entry: e,
                  onDeleted: () async {
                    await ref.read(transactionRepoProvider).softDelete(e.id);
                    await ref.read(balanceProvider.notifier).load();
                    await ref.read(transactionsProvider.notifier).load();
                    setState(() {});
                  },
                  onUpdated: () async {
                    await ref.read(balanceProvider.notifier).load();
                    await ref.read(transactionsProvider.notifier).load();
                    setState(() {});
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

  Future<void> _showPeriodSheet() async {
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
              trailing: period == Period.weekly
                  ? const Icon(Icons.check)
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Monthly'),
              onTap: () => Navigator.pop(context, Period.monthly),
              trailing: period == Period.monthly
                  ? const Icon(Icons.check)
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Yearly'),
              onTap: () => Navigator.pop(context, Period.yearly),
              trailing: period == Period.yearly
                  ? const Icon(Icons.check)
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (sel != null) {
      setState(() {
        period = sel;
        switch (period) {
          case Period.weekly:
            anchor = _startOfWeek(anchor);
            break;
          case Period.monthly:
            anchor = DateTime(anchor.year, anchor.month, 1);
            break;
          case Period.yearly:
            anchor = DateTime(anchor.year, 1, 1);
            break;
        }
      });
    }
  }

  Future<void> _showAccountPicker() async {
    final accounts = await ref.read(accountRepoProvider).findAllActive();
    if (!mounted) return;
    final picked = await showModalBottomSheet<Account>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(8),
          itemBuilder: (c, i) {
            final a = accounts[i];
            return ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: Text(a.code ?? ""),
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
      // Update the shared selection -> HomePage AppBar reacts automatically.
      ref.read(selectedAccountIdProvider.notifier).state = picked.id;

      // Optional: refresh balance and transactions after account switch
      await ref.read(balanceProvider.notifier).load();
      await ref.read(transactionsProvider.notifier).load();
      if (mounted) setState(() {});
    }
  }

  Future<void> _showShareDialog(Account acc) async {
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
              if (mounted) Navigator.pop(context);
              if (mounted) {
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
    final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
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
          Text(
            '${net >= 0 ? '+' : ''}${net ~/ 100}',
            style: TextStyle(color: netColor, fontWeight: FontWeight.w700),
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
    final time = DateFormat.Hm().format(entry.dateTransaction);
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
        subtitle: Text(time),
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
          if (ok == true) await onUpdated();
        },
      ),
    );
  }
}

class _TxnSearchDelegate extends SearchDelegate<TransactionEntry?> {
  final List<TransactionEntry> items;
  _TxnSearchDelegate(this.items);

  List<TransactionEntry> _filter(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((e) {
      final text = '${e.code ?? ''} ${e.description ?? ''}'.toLowerCase();
      return text.contains(query);
    }).toList();
  }

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);
  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final filtered = _filter(query);
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = filtered[i];
        final isDebit = e.typeEntry == 'DEBIT';
        final color = isDebit ? Colors.red : Colors.green;
        final sign = isDebit ? '-' : '+';
        return ListTile(
          title: Text(
            e.description ?? e.code ?? 'Transaction',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(DateFormat.yMMMd().add_Hm().format(e.dateTransaction)),
          trailing: Text(
            '$sign${e.amount ~/ 100}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          onTap: () => close(context, e),
        );
      },
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );
}
