import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/account_selection.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_quick_add_sheet.dart';
import 'package:money_pulse/presentation/features/settings/settings_page.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/domain/accounts/entities/account.dart';
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
      await ref.read(transactionsProvider.notifier).load();
      await ref.read(categoriesProvider.notifier).load();
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
      setState(() {});
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
      if (mounted) setState(() {});
    }
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
        title: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: _showAccountPicker,
          child: accAsync.when(
            loading: () => Row(
              children: [
                const Text('...'),
                const Spacer(),
                MoneyText(
                  amountCents: 0,
                  currency: 'XOF',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            error: (_, __) => Row(
              children: [
                const Text('Account'),
                const Spacer(),
                MoneyText(
                  amountCents: 0,
                  currency: 'XOF',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            data: (acc) => Row(
              children: [
                Text(acc?.code ?? 'Account'),
                const SizedBox(width: 8),
                const Spacer(),
                MoneyText(
                  amountCents: acc?.balance ?? 0,
                  currency: acc?.currency ?? 'XOF',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
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
