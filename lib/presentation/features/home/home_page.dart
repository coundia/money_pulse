import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/account_selection.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_quick_add_sheet.dart';
import 'package:money_pulse/presentation/features/settings/settings_page.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/features/transactions/providers/transaction_list_providers.dart';
import 'package:money_pulse/presentation/features/transactions/search/txn_search_delegate.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_form_sheet.dart';
import 'package:money_pulse/presentation/features/transactions/controllers/transaction_list_controller.dart';
import 'package:money_pulse/presentation/features/transactions/models/transaction_filters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../transactions/pages/transaction_list_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int pageIdx = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // Load base data
      await ref.read(transactionsProvider.notifier).load();
      await ref.read(categoriesProvider.notifier).load();

      await ref.read(ensureSelectedAccountProvider.future);
    });
  }

  Future<void> _openQuickAdd() async {
    final ok = await showRightDrawer<bool>(
      context,
      child: const TransactionQuickAddSheet(),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (ok == true) {
      await ref.read(transactionsProvider.notifier).load();
      await ref.read(balanceProvider.notifier).load();
      if (mounted) setState(() {});
    }
  }

  Future<void> _showAccountPicker() async {
    if (!mounted) return;

    final picked = await showModalBottomSheet<Account>(
      context: context,
      builder: (_) => SafeArea(
        child: FutureBuilder<List<Account>>(
          // Ensure balances are recalculated, then fetch fresh accounts
          future: ref
              .read(balanceProvider.notifier)
              .load()
              .then((_) => ref.read(accountRepoProvider).findAllActive()),
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final accounts = snap.data ?? const <Account>[];
            return ListView.separated(
              padding: const EdgeInsets.all(8),
              itemBuilder: (c, i) {
                final a = accounts[i];
                return ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: Text(a.code ?? ''),
                  subtitle: MoneyText(
                    amountCents: a.balance,
                    currency:
                        a.currency ?? 'XOF', // use account currency if set
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  trailing: (ref.read(selectedAccountIdProvider) ?? '') == a.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(c, a),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: accounts.length,
            );
          },
        ),
      ),
    );

    if (picked != null) {
      ref.read(selectedAccountIdProvider.notifier).state = picked.id;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLastAccountIdKey, picked.id);

      // keep everything in sync
      await ref.read(balanceProvider.notifier).load();
      await ref.read(transactionsProvider.notifier).load();

      if (mounted) setState(() {});
    }
  }

  Future<void> _showPeriodSheet() async {
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

  int get _navSelectedIndex => pageIdx == 0 ? 0 : 2;

  void _onDestinationSelected(int v) {
    if (v == 1) {
      _openQuickAdd();
      return;
    }
    setState(() => pageIdx = (v == 0) ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final accAsync = ref.watch(selectedAccountProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true, // <- montant centré
        title: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: _showAccountPicker, // on continue d’ouvrir le picker au tap
          child: accAsync.when(
            loading: () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MoneyText(
                  amountCents: 0,
                  currency: 'XOF',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                const Text('...', style: TextStyle(fontSize: 12)),
              ],
            ),
            error: (_, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MoneyText(
                  amountCents: 0,
                  currency: 'XOF',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                const Text('Account', style: TextStyle(fontSize: 12)),
              ],
            ),
            data: (acc) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MoneyText(
                  amountCents: acc?.balance ?? 0,
                  currency: acc?.currency ?? 'XOF',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      acc?.code ?? 'Account',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (pageIdx == 0)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (action) async {
                switch (action) {
                  case 'search':
                    final items = await ref.read(
                      transactionListItemsProvider.future,
                    );
                    final result = await showSearch<TransactionEntry?>(
                      context: context,
                      delegate: TxnSearchDelegate(items),
                    );
                    if (result != null) {
                      final ok = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => TransactionFormSheet(entry: result),
                      );
                      if (ok == true) {
                        await ref.read(balanceProvider.notifier).load();
                        await ref.read(transactionsProvider.notifier).load();
                      }
                    }
                    break;
                  case 'period':
                    await _showPeriodSheet();
                    break;
                  case 'changeAccount':
                    await _showAccountPicker();
                    break;
                  case 'sync':
                    if (!mounted) break;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sync started… (demo)')),
                    );
                    await Future.delayed(const Duration(milliseconds: 800));
                    if (!mounted) break;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sync complete')),
                    );
                    break;
                  case 'share':
                    final acc = await ref.read(selectedAccountProvider.future);
                    if (!mounted || acc == null) break;
                    await _showShareDialog(acc);
                    break;
                  case 'settings':
                    if (!mounted) break;
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'search',
                  child: ListTile(
                    leading: Icon(Icons.search),
                    title: Text('Search'),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'period',
                  child: ListTile(
                    leading: Icon(Icons.filter_alt),
                    title: Text('Select period'),
                  ),
                ),
                PopupMenuItem(
                  value: 'changeAccount',
                  child: ListTile(
                    leading: Icon(Icons.account_balance_wallet),
                    title: Text('Change account'),
                  ),
                ),
                PopupMenuItem(
                  value: 'sync',
                  child: ListTile(
                    leading: Icon(Icons.sync),
                    title: Text('Sync transactions'),
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.ios_share),
                    title: Text('Share account'),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Settings'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: IndexedStack(
        index: pageIdx,
        children: const [TransactionListPage(), SettingsPage()],
      ),
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        selectedIndex: _navSelectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle, size: 36),
            selectedIcon: Icon(Icons.add_circle, size: 36),
            label: 'Add',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'COMPTE'),
        ],
      ),
    );
  }
}
