import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/features/pos/pos_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/account_selection.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import 'package:money_pulse/presentation/features/settings/settings_page.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_quick_add_sheet.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_form_sheet.dart';
import 'package:money_pulse/presentation/features/transactions/pages/transaction_list_page.dart';
import 'package:money_pulse/presentation/features/transactions/search/txn_search_delegate.dart';

import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';

import 'package:money_pulse/presentation/features/accounts/account_page.dart';
import 'package:money_pulse/presentation/features/categories/category_list_page.dart';

import '../transactions/controllers/transaction_list_controller.dart';
import '../transactions/providers/transaction_list_providers.dart'
    show transactionListItemsProvider;

import 'widgets/account_picker_sheet.dart';
import 'widgets/period_picker_sheet.dart';
import 'widgets/share_account_dialog.dart';

import 'package:money_pulse/presentation/shared/formatters.dart';

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
      await ref.read(transactionsProvider.notifier).load();
      await ref.read(categoriesProvider.notifier).load();
      await ref.read(ensureSelectedAccountProvider.future);
      ref.invalidate(selectedAccountProvider);
      ref.invalidate(transactionListItemsProvider);
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
      ref.invalidate(selectedAccountProvider);
      ref.invalidate(transactionListItemsProvider);
      if (mounted) setState(() {});
    }
  }

  Future<void> _showAccountPicker() async {
    if (!mounted) return;
    final picked = await showAccountPickerSheet(
      context: context,
      accountsFuture: ref
          .read(balanceProvider.notifier)
          .load()
          .then((_) => ref.read(accountRepoProvider).findAllActive()),
      selectedAccountId: ref.read(selectedAccountIdProvider),
    );
    if (picked != null) {
      ref.read(selectedAccountIdProvider.notifier).state = picked.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLastAccountIdKey, picked.id);
      await ref.read(balanceProvider.notifier).load();
      await ref.read(transactionsProvider.notifier).load();
      ref.invalidate(selectedAccountProvider);
      ref.invalidate(transactionListItemsProvider);
      if (mounted) setState(() {});
    }
  }

  Future<void> _showPeriodSheet() async {
    final state = ref.read(transactionListStateProvider);
    final sel = await showPeriodPickerSheet(
      context: context,
      current: state.period,
    );
    if (sel != null) {
      ref.read(transactionListStateProvider.notifier).setPeriod(sel);
      ref.invalidate(transactionListItemsProvider);
      if (mounted) setState(() {});
    }
  }

  Future<void> _showShareDialog(Account acc) async {
    await showShareAccountDialog(context: context, acc: acc);
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
        centerTitle: true,
        title: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: _showAccountPicker,
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
                const Text('…', style: TextStyle(fontSize: 12)),
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
                const Text('Compte', style: TextStyle(fontSize: 12)),
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
                      acc?.code ?? 'Compte',
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
              tooltip: 'Plus',
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
                        ref.invalidate(selectedAccountProvider);
                        ref.invalidate(transactionListItemsProvider);
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
                      const SnackBar(
                        content: Text('Synchronisation démarrée…'),
                      ),
                    );
                    await Future.delayed(const Duration(milliseconds: 800));
                    if (!mounted) break;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Synchronisation terminée')),
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
                  case 'manageCategories':
                    if (!mounted) break;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CategoryListPage(),
                      ),
                    );
                    break;
                  case 'manageAccounts':
                    if (!mounted) break;
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountPage()),
                    );
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'search',
                  child: ListTile(
                    leading: Icon(Icons.search),
                    title: Text('Rechercher'),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'period',
                  child: ListTile(
                    leading: Icon(Icons.filter_alt),
                    title: Text('Sélectionner la période'),
                  ),
                ),
                PopupMenuItem(
                  value: 'changeAccount',
                  child: ListTile(
                    leading: Icon(Icons.account_balance_wallet),
                    title: Text('Changer de compte'),
                  ),
                ),
                PopupMenuItem(
                  value: 'sync',
                  child: ListTile(
                    leading: Icon(Icons.sync),
                    title: Text('Synchroniser les transactions'),
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.ios_share),
                    title: Text('Partager le compte'),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'manageCategories',
                  child: ListTile(
                    leading: Icon(Icons.category_outlined),
                    title: Text('Catégories'),
                  ),
                ),
                PopupMenuItem(
                  value: 'manageAccounts',
                  child: ListTile(
                    leading: Icon(Icons.account_balance_wallet_outlined),
                    title: Text('Comptes'),
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Paramètres'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: IndexedStack(
        index: pageIdx,
        children: const [TransactionListPage(), PosPage()],
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
            label: 'Ajouter',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Compte'),
        ],
      ),
    );
  }
}
