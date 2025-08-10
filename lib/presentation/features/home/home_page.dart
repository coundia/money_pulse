import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/widgets/money_text.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_list_page.dart';
import 'package:money_pulse/presentation/features/categories/category_list_page.dart';
import 'package:money_pulse/presentation/features/reports/report_page.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_quick_add_sheet.dart';
import 'package:money_pulse/presentation/features/categories/category_form_sheet.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int idx = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(balanceProvider.notifier).load();
      await ref.read(transactionsProvider.notifier).load();
      await ref.read(categoriesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final balanceCents = ref.watch(balanceProvider);

    Widget? fab;
    if (idx == 0) {
      fab = FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const TransactionQuickAddSheet(),
          );
          if (ok == true) {
            await ref.read(balanceProvider.notifier).load();
            await ref.read(transactionsProvider.notifier).load();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      );
    } else if (idx == 1) {
      fab = FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const CategoryFormSheet(),
          );
          if (ok == true) {
            await ref.read(categoriesProvider.notifier).load();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      );
    }

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
        index: idx,
        children: const [
          TransactionListPage(),
          CategoryListPage(),
          ReportPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (v) => setState(() => idx = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Reports'),
        ],
      ),
      floatingActionButton: fab,
    );
  }
}
