/* Home page scaffold using SyncAll to push all dirty tables after access verification. */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/account_selection.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';

import 'package:money_pulse/presentation/features/settings/settings_page.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_form_sheet.dart';
import 'package:money_pulse/presentation/features/transactions/pages/transaction_list_page.dart';
import 'package:money_pulse/presentation/features/transactions/search/txn_search_delegate.dart';

import 'package:money_pulse/presentation/features/products/product_list_page.dart';
import 'package:money_pulse/presentation/features/customers/customer_list_page.dart';
import 'package:money_pulse/presentation/features/pos/pos_page.dart';

import 'package:money_pulse/presentation/features/accounts/account_page.dart';
import 'package:money_pulse/presentation/features/categories/category_list_page.dart';

import 'package:money_pulse/domain/accounts/entities/account.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';

import '../../../sync/infrastructure/pull_providers.dart';
import '../../../sync/infrastructure/sync_logger.dart';
import '../transactions/controllers/transaction_list_controller.dart';
import '../transactions/prefs/summary_card_prefs_panel.dart';
import '../transactions/providers/transaction_list_providers.dart'
    show transactionListItemsProvider;

import 'prefs/home_privacy_prefs_provider.dart';
import 'widgets/account_picker_sheet.dart';
import 'widgets/period_picker_sheet.dart';
import 'widgets/share_account_dialog.dart';

import 'prefs/home_ui_prefs_provider.dart';
import 'prefs/home_ui_prefs_panel.dart';

import 'widgets/home_app_bar_title.dart';

import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';

// ⬇️ Import sync orchestrator
import 'package:money_pulse/sync/sync_service_provider.dart';

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
      await ref.read(accessSessionProvider.notifier).restore();
    });
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

  Future<void> openSummaryPrefs() async {
    await showRightDrawer(
      context,
      child: const SummaryCardPrefsPanel(),
      widthFraction: 0.86,
      heightFraction: 1.0,
    );
  }

  Future<void> openUiPrefs() async {
    await showRightDrawer(
      context,
      child: const HomeUiPrefsPanel(),
      widthFraction: 0.86,
      heightFraction: 1.0,
    );
  }

  Future<void> _runPullAndPush() async {
    await _runPullAll();
    await _runSyncAll();
  }

  Future<void> _runSyncAll() async {
    final ok = await requireAccess(context, ref);
    if (!mounted || !ok) return;

    final logger = ref.read(syncLoggerProvider);
    logger.info('************** PUSH *****');

    try {
      logger.info('UI: trigger syncAll');
      final s = await syncAllTables(ref);
      logger.info(
        'UI: syncAll success cats=${s.categories} accs=${s.accounts} txs=${s.transactions} '
        'uts=${s.units} prods=${s.products} items=${s.items} comps=${s.companies} '
        'custs=${s.customers} debts=${s.debts} sl=${s.stockLevels} sm=${s.stockMovements}',
      );

      await ref.read(balanceProvider.notifier).load();
      await ref.read(transactionsProvider.notifier).load();
      ref.invalidate(selectedAccountProvider);
      ref.invalidate(transactionListItemsProvider);
      setState(() {});
    } catch (e, st) {
      logger.error('UI: syncAll failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur de synchronisation')),
      );
    }
  }

  Future<void> _runPullAll() async {
    try {
      ref.read(syncLoggerProvider).info('UI: trigger pullAll');
      final sum = await pullAllTables(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import terminé • Comptes: ${sum.accounts}, Catégories: ${sum.categories}, Clients: ${sum.customers}',
          ),
        ),
      );
      await ref.read(balanceProvider.notifier).load();
      await ref.read(transactionsProvider.notifier).load();
      ref.invalidate(selectedAccountProvider);
      if (mounted) setState(() {});
    } catch (e, st) {
      ref.read(syncLoggerProvider).error('UI: pullAll failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec import: $e')));
    }
  }

  void _onDestinationSelected(int v) {
    if (!mounted) return;
    setState(() => pageIdx = v);
  }

  @override
  Widget build(BuildContext context) {
    final accAsync = ref.watch(selectedAccountProvider);
    final uiPrefs = ref.watch(homeUiPrefsProvider);
    final privacyAsync = ref.watch(homePrivacyPrefsProvider);
    final accessGrant = ref.watch(accessSessionProvider);

    final hide = privacyAsync.maybeWhen(
      data: (p) => p.hideBalance,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: HomeAppBarTitle(
          accountAsync: accAsync,
          onTap: _showAccountPicker,
          hideAmounts: hide,
          onToggleHide: () =>
              ref.read(homePrivacyPrefsProvider.notifier).toggleHideBalance(),
        ),
        actions: [
          if (pageIdx == 0)
            PopupMenuButton<String>(
              tooltip: 'Plus',
              onSelected: (action) async {
                switch (action) {
                  case 'login':
                    {
                      final ok = await requireAccess(context, ref);
                      if (!mounted || !ok) break;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Connecté avec succès.')),
                      );
                      break;
                    }
                  case 'logout':
                    {
                      await ref.read(accessSessionProvider.notifier).clear();
                      if (!mounted) break;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Déconnecté.')),
                      );
                      break;
                    }
                  case 'search':
                    {
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
                    }
                  case 'period':
                    await _showPeriodSheet();
                    break;
                  case 'sync':
                    await _runPullAndPush();
                    break;
                  case 'share':
                    {
                      final ok = await requireAccess(context, ref);
                      if (!mounted || !ok) break;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Accès vérifié. partage todo.'),
                        ),
                      );
                      break;
                    }
                  case 'personnalisation':
                    if (!mounted) break;
                    await openSummaryPrefs();
                    break;
                  case 'ui':
                    if (!mounted) break;
                    await openUiPrefs();
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
                      MaterialPageRoute(
                        builder: (_) => const AccountListPage(),
                      ),
                    );
                    break;
                  case 'clients':
                    if (!mounted) break;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CustomerListPage(),
                      ),
                    );
                    break;
                  case 'produits':
                    if (!mounted) break;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProductListPage(),
                      ),
                    );
                    break;
                  case 'settings':
                    if (!mounted) break;
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                    break;
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuEntry<String>>[];

                items.addAll(const [
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
                    value: 'sync',
                    child: ListTile(
                      leading: Icon(Icons.sync),
                      title: Text('Synchroniser '),
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
                    value: 'produits',
                    child: ListTile(
                      leading: Icon(Icons.shop),
                      title: Text('Produits'),
                    ),
                  ),
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
                      leading: Icon(Icons.wallet_giftcard),
                      title: Text('Comptes'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clients',
                    child: ListTile(
                      leading: Icon(Icons.person),
                      title: Text('Clients'),
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'personnalisation',
                    child: ListTile(
                      leading: Icon(Icons.dashboard_customize),
                      title: Text('Personnalisation'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Paramètres'),
                    ),
                  ),
                ]);
                items.add(const PopupMenuDivider());
                items.add(
                  PopupMenuItem(
                    value: accessGrant == null ? 'login' : 'logout',
                    child: ListTile(
                      leading: Icon(
                        accessGrant == null ? Icons.login : Icons.logout,
                      ),
                      title: Text(
                        accessGrant == null ? 'Se connecter' : 'Se déconnecter',
                      ),
                    ),
                  ),
                );

                return items;
              },
            ),
        ],
      ),
      body: IndexedStack(
        index: pageIdx,
        children: const [TransactionListPage(), PosPage(), SettingsPage()],
      ),
      bottomNavigationBar: uiPrefs.showBottomNav
          ? NavigationBar(
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              selectedIndex: pageIdx,
              onDestinationSelected: _onDestinationSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.list_alt),
                  label: 'Transactions',
                ),
                NavigationDestination(
                  icon: Icon(Icons.point_of_sale),
                  label: 'POS',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
