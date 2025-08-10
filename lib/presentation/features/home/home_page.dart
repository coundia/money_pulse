import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/account_selection.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_quick_add_sheet.dart';
import 'package:money_pulse/presentation/features/settings/settings_page.dart';
import 'package:money_pulse/presentation/widgets/left_drawer.dart';
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
    final ok = await showLeftDrawer<bool>(
      context,
      child: const TransactionQuickAddSheet(),
      widthFraction: 0.92,
    );
    if (ok == true) {
      await ref.read(transactionsProvider.notifier).load();
      setState(() {});
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
        title: accAsync.when(
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
