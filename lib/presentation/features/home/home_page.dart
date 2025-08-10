import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_list_page.dart';
import 'package:money_pulse/presentation/features/reports/report_page.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_quick_add_sheet.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// Page index: 0 = Transactions, 1 = Reports
  int pageIdx = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(balanceProvider.notifier).load();
      await ref.read(transactionsProvider.notifier).load();
      await ref.read(categoriesProvider.notifier).load();
    });
  }

  Future<void> _openQuickAdd() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const TransactionQuickAddSheet(),
    );
    if (ok == true) {
      await ref.read(balanceProvider.notifier).load();
      await ref.read(transactionsProvider.notifier).load();
      setState(() {}); // refresh
    }
  }

  /// Map current page -> selected destination index (0=Tx, 1=Add action (not selected), 2=Reports)
  int get _navSelectedIndex => pageIdx == 0 ? 0 : 2;

  void _onDestinationSelected(int v) {
    if (v == 1) {
      // central "+" action: quick add transaction
      _openQuickAdd();
      return;
    }
    setState(() {
      // 0 -> Transactions page(0), 2 -> Reports page(1)
      pageIdx = (v == 0) ? 0 : 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final balanceCents = ref.watch(balanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Money Pulse'),
            const Spacer(),
            MoneyText(
              amountCents: balanceCents,
              currency: 'XOF',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: pageIdx,
        children: const [TransactionListPage(), ReportPage()],
      ),
      bottomNavigationBar: NavigationBar(
        labelBehavior:
            NavigationDestinationLabelBehavior.onlyShowSelected, // hide labels
        selectedIndex: _navSelectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'Transactions', // hidden by labelBehavior
          ),
          NavigationDestination(
            // big + icon, no visible label
            icon: Icon(Icons.add_circle, size: 36),
            selectedIcon: Icon(Icons.add_circle, size: 36),
            label: 'Add', // hidden
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart),
            label: 'Reports', // hidden by labelBehavior
          ),
        ],
      ),
    );
  }
}
