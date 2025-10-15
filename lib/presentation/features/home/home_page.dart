// File: lib/presentation/app/home/home_page.dart
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/app/account_selection.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/app/restart_app.dart';
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
import 'package:sqflite/sqlite_api.dart';
import '../../../sync/infrastructure/pull_ports/account_pull_port_sqflite.dart';
import '../../../sync/infrastructure/pull_providers.dart';
import '../../../sync/infrastructure/sync_api_client.dart';
import '../../../sync/infrastructure/sync_logger.dart';
import '../../app/home/home_page_refresh_hook.dart';
import '../accounts/account_share_screen.dart';
import '../transactions/controllers/transaction_list_controller.dart';
import '../transactions/prefs/summary_card_prefs_panel.dart';
import '../transactions/providers/transaction_list_providers.dart'
    show transactionListItemsProvider;
import 'prefs/home_privacy_prefs_provider.dart';
import 'widgets/account_picker_sheet.dart';
import 'widgets/period_picker_sheet.dart';
import 'prefs/home_ui_prefs_provider.dart';
import 'prefs/home_ui_prefs_panel.dart';
import 'widgets/home_app_bar_title.dart';
import 'package:money_pulse/onboarding/presentation/providers/access_session_provider.dart';
import 'package:money_pulse/sync/sync_service_provider.dart';
import 'package:money_pulse/onboarding/presentation/flows/logout_and_purge_flow.dart';
import 'package:money_pulse/presentation/widgets/under_construction_drawer.dart'
    hide showRightDrawer;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  int pageIdx = 0;
  bool _isBusy = false;
  int _remountSeed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    dev.log('initState → restore session + preload data', name: 'HomePage');
    Future.microtask(() async {
      await ref.read(accessSessionProvider.notifier).restore();
      await HomeRefreshHook.onStartup(ref);
      await ref.read(transactionsProvider.notifier).load();
      await ref.read(categoriesProvider.notifier).load();
      await ref.read(ensureSelectedAccountProvider.future);
      ref.invalidate(selectedAccountProvider);
      ref.invalidate(transactionListItemsProvider);
      dev.log('Bootstrap finished', name: 'HomePage');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    dev.log('dispose()', name: 'HomePage');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      dev.log('App resumed → refreshAll(remount: true)', name: 'HomePage');
      _refreshAll(remount: true);
    }
  }

  Future<void> _softReload() async {
    dev.log(
      '_softReload → reloading balances, categories, transactions',
      name: 'HomePage',
    );
    await ref.read(balanceProvider.notifier).load();
    await ref.read(categoriesProvider.notifier).load();
    await ref.read(transactionsProvider.notifier).load();
    ref.invalidate(selectedAccountProvider);
    ref.invalidate(transactionListItemsProvider);
  }

  void _hardRemount() {
    dev.log('_hardRemount → increment seed', name: 'HomePage');
    setState(() => _remountSeed++);
  }

  Future<void> _refreshAll({bool remount = true}) async {
    dev.log('_refreshAll start', name: 'HomePage');
    setState(() => _isBusy = true);
    try {
      await HomeRefreshHook.onManualRefresh(ref);
      //RestartApp.restart(context); // bug when upload image
      dev.log('_refreshAll done (RestartApp)', name: 'HomePage');
    } catch (e, st) {
      dev.log(
        'Error in _refreshAll',
        name: 'HomePage',
        error: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<T?> _pushAndRefresh<T>(Widget page) async {
    dev.log('push → ${page.runtimeType}', name: 'HomePage');
    final res = await Navigator.of(
      context,
    ).push<T>(MaterialPageRoute(builder: (_) => page));
    dev.log('pop ← ${page.runtimeType}', name: 'HomePage');
    await _refreshAll(remount: true);
    return res;
  }

  Future<void> _showAccountPicker() async {
    dev.log('Opening account picker', name: 'HomePage');
    if (!mounted) return;
    final repo = ref.read(accountRepoProvider);
    final selectedIdPref = ref.read(selectedAccountIdProvider);
    final accountsFuture = ref
        .read(balanceProvider.notifier)
        .load()
        .then((_) => repo.findAllActive())
        .then((list) async {
          final defaults = list.where((a) => a.isDefault).toList();
          if (list.isNotEmpty && defaults.length != 1) {
            final target = list.firstWhere(
              (a) => a.id == (selectedIdPref ?? ''),
              orElse: () => list.first,
            );
            await repo.update(target.copyWith(isDefault: true));
            return await repo.findAllActive();
          }
          return list;
        });

    final picked = await showAccountPickerSheet(
      context: context,
      accountsFuture: accountsFuture,
      selectedAccountId: ref.read(selectedAccountIdProvider),
    );

    if (picked != null) {
      dev.log('Picked account: ${picked.code}', name: 'HomePage');
      try {
        await repo.setDefault(picked.id);
      } catch (_) {
        await repo.update(picked.copyWith(isDefault: true));
      }
      ref.read(selectedAccountIdProvider.notifier).state = picked.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLastAccountIdKey, picked.id);
      await _softReload();
      _hardRemount();
    }
  }

  Future<void> _showPeriodSheet() async {
    dev.log('Opening period picker', name: 'HomePage');
    final state = ref.read(transactionListStateProvider);
    final sel = await showPeriodPickerSheet(
      context: context,
      current: state.period,
    );
    if (sel != null) {
      dev.log('Period selected: $sel', name: 'HomePage');
      ref.read(transactionListStateProvider.notifier).setPeriod(sel);
      ref.invalidate(transactionListItemsProvider);
      _hardRemount();
    }
  }

  Future<void> openSummaryPrefs() async {
    dev.log('Open SummaryCardPrefsPanel', name: 'HomePage');
    await showRightDrawer(
      context,
      child: const SummaryCardPrefsPanel(),
      widthFraction: 0.86,
      heightFraction: 1.0,
    );
  }

  Future<void> openUiPrefs() async {
    dev.log('Open HomeUiPrefsPanel', name: 'HomePage');
    await showRightDrawer(
      context,
      child: const HomeUiPrefsPanel(),
      widthFraction: 0.86,
      heightFraction: 1.0,
    );
  }

  Future<void> _runPullAndPush() async {
    dev.log('Start pull + push full sync', name: 'HomePage');
    await _runPullAndUpdateRemoteIdOnly();
    await _runSyncAll();
    await _runPullAll();
    await _refreshAll(remount: true);
  }

  Future<void> _runPullAndUpdateRemoteIdOnly() async {
    final logger = ref.read(syncLoggerProvider);
    try {
      logger.info('UI: adopt remoteId for accounts (no balance update)');
      final baseUri = ref.read(syncBaseUriProvider);
      final api = ref.read(syncApiClientProvider(baseUri));
      final Database dbRaw = ref.read(dbProvider).db;
      final port = AccountPullPortSqflite(dbRaw);
      final since = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final items = await api.getAccountsSince(since);
      if (items.isEmpty) {
        logger.info('Adopt remoteId: no server items');
        return;
      }
      final adopted = await port.adoptRemoteIds(items);
      logger.info('Adopt remoteId: adopted=$adopted row(s)');
    } catch (e, st) {
      logger.error('UI: adopt remoteId failed', e, st);
      dev.log(
        'Adopt remoteId failed',
        name: 'HomePage',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Échec adoption remoteId')));
    }
  }

  Future<void> _runSyncAll() async {
    dev.log('Trigger syncAll', name: 'HomePage');
    final ok = await requireAccess(context, ref);
    if (!mounted || !ok) return;
    final logger = ref.read(syncLoggerProvider);
    logger.info('************** PUSH *****');
    try {
      await syncAllTables(ref);
      logger.info('UI: syncAll completed');
    } catch (e, st) {
      logger.error('UI: syncAll failed', e, st);
      dev.log('SyncAll failed', name: 'HomePage', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur de synchronisation')),
      );
    }
  }

  Future<void> _runPullAll() async {
    dev.log('Trigger pullAll', name: 'HomePage');
    try {
      final sum = await pullAllTables(ref);
      dev.log('PullAll done: ${sum.toString()}', name: 'HomePage');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import terminé • Comptes: ${sum.accounts}, Catégories: ${sum.categories}, Clients: ${sum.customers}',
          ),
        ),
      );
    } catch (e, st) {
      dev.log('PullAll failed', name: 'HomePage', error: e, stackTrace: st);
      ref.read(syncLoggerProvider).error('UI: pullAll failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec import: $e')));
    }
  }

  void _onDestinationSelected(int v) {
    dev.log('BottomNav → index=$v', name: 'HomePage');
    if (!mounted) return;
    setState(() => pageIdx = v);
  }

  Future<void> _openShareDrawer() async {
    dev.log('Opening share drawer', name: 'HomePage');
    Account? acc = ref
        .read(selectedAccountProvider)
        .maybeWhen(data: (a) => a, orElse: () => null);
    if (acc == null) {
      await ref.read(ensureSelectedAccountProvider.future);
      acc = ref
          .read(selectedAccountProvider)
          .maybeWhen(data: (a) => a, orElse: () => null);
    }
    if (acc == null) {
      final repo = ref.read(accountRepoProvider);
      final accountsFuture = repo.findAllActive();
      final picked = await showAccountPickerSheet(
        context: context,
        accountsFuture: accountsFuture,
        selectedAccountId: ref.read(selectedAccountIdProvider),
      );
      if (picked == null) return;
      acc = picked;
    }
    await openAccountShareScreen<void>(
      context,
      accountId: acc!.id,
      accountName: acc.description?.isNotEmpty == true
          ? acc.description
          : acc.code,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accAsync = ref.watch(selectedAccountProvider);
    final uiPrefs = ref.watch(homeUiPrefsProvider);
    final privacyAsync = ref.watch(homePrivacyPrefsProvider);
    final hide = privacyAsync.maybeWhen(
      data: (p) => p.hideBalance,
      orElse: () => false,
    );

    dev.log('build() → pageIdx=$pageIdx busy=$_isBusy', name: 'HomePage');

    return KeyedSubtree(
      key: ValueKey(_remountSeed),
      child: Scaffold(
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
                  dev.log('Popup selected: $action', name: 'HomePage');
                  switch (action) {
                    case 'refresh':
                      await _runPullAll();
                      await _refreshAll(remount: true);
                      break;
                    case 'login':
                      final ok = await requireAccess(context, ref);
                      if (!mounted || !ok) break;
                      await HomeRefreshHook.onManualRefresh(ref);
                      await _runPullAll();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Connecté avec succès.')),
                      );
                      break;
                    case 'logout':
                      await runLogoutAndPurgeFlow(context, ref);
                      break;
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
                        if (ok == true) await _refreshAll(remount: true);
                      }
                      break;
                    case 'period':
                      await _showPeriodSheet();
                      break;
                    case 'sync':
                      await _runPullAndPush();
                      break;
                    case 'share':
                      final ok = await requireAccess(context, ref);
                      if (!mounted || !ok) break;
                      await _openShareDrawer();
                      break;
                    case 'personnalisation':
                      await openSummaryPrefs();
                      break;
                    case 'ui':
                      await openUiPrefs();
                      break;
                    case 'manageCategories':
                      await _pushAndRefresh(const CategoryListPage());
                      break;
                    case 'manageAccounts':
                      await _pushAndRefresh(const AccountListPage());
                      break;
                    case 'clients':
                      await _pushAndRefresh(const CustomerListPage());
                      break;
                    case 'produits':
                      await _pushAndRefresh(const ProductListPage());
                      break;
                    case 'settings':
                      await _pushAndRefresh(const SettingsPage());
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'refresh',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Rafraîchir'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'search',
                    child: ListTile(
                      leading: Icon(Icons.search),
                      title: Text('Rechercher'),
                    ),
                  ),
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
                      title: Text('Synchroniser'),
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
                ],
              ),
          ],
          bottom: _isBusy
              ? const PreferredSize(
                  preferredSize: Size(double.infinity, 3),
                  child: LinearProgressIndicator(minHeight: 3),
                )
              : null,
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
      ),
    );
  }
}
