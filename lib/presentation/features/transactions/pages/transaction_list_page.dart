// Screen that lists transactions, groups by day, shows summary and wires tile actions with optional auto refresh on focus.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:jaayko/domain/transactions/entities/transaction_entry.dart';
import 'package:jaayko/presentation/app/providers.dart';
import 'package:jaayko/presentation/widgets/right_drawer.dart';
import 'package:jaayko/presentation/features/transactions/transaction_quick_add_sheet.dart';
import 'package:jaayko/presentation/features/transactions/providers/transaction_list_providers.dart';
import 'package:jaayko/presentation/features/transactions/utils/transaction_grouping.dart';
import 'package:jaayko/presentation/features/transactions/widgets/day_header.dart';
import 'package:jaayko/presentation/features/transactions/widgets/transaction_tile.dart';
import 'package:jaayko/presentation/features/transactions/widgets/transaction_summary_card.dart';
import 'package:jaayko/presentation/features/transactions/search/txn_search_delegate.dart';
import 'package:jaayko/presentation/features/transactions/search/widgets/txn_search_cta.dart';
import 'package:jaayko/presentation/features/settings/settings_page.dart';
import 'package:jaayko/presentation/features/reports/report_page.dart';
import 'package:jaayko/presentation/app/account_selection.dart';

import 'package:jaayko/presentation/widgets/auto_refresh_on_focus.dart';
import 'package:jaayko/sync/infrastructure/pull_providers.dart';
import 'package:jaayko/sync/infrastructure/sync_logger.dart';

import 'package:jaayko/onboarding/presentation/providers/access_session_provider.dart';

import '../../../../shared/server_unavailable.dart';
import '../../../app/restart_app.dart';
import '../../settings/app_settings_provider.dart';
import '../controllers/transaction_list_controller.dart';

class TransactionListPage extends ConsumerWidget {
  const TransactionListPage({super.key});

  String _formatCurrency(int cents) {
    final format = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'XOF',
      decimalDigits: 0,
    );
    return format.format(cents / 100);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionListStateProvider);
    final itemsAsync = ref.watch(transactionListItemsProvider);

    Future<void> _refreshLocal() async {
      await ref.read(transactionsProvider.notifier).load();
      await ref.read(balanceProvider.notifier).load();
      ref.invalidate(transactionListItemsProvider);
    }

    Future<void> _pullFromApiAndRefresh() async {
      bool online = ref.read(accessSessionProvider) != null;
      if (!online) {
        final ok = await requireAccess(context, ref);
        online = ok && ref.read(accessSessionProvider) != null;
      }
      if (!online) {
        await _refreshLocal();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hors ligne : données locales mises à jour'),
            ),
          );
        }
        return;
      }
      try {
        ref.read(syncLoggerProvider).info('TxnList: pullAll (manual/auto)');
        await pullAllTables(ref);
      } catch (e, st) {
        ref.read(syncLoggerProvider).error('TxnList: pullAll failed', e, st);
        if (context.mounted) {
          ServerUnavailable.showSnackBar(
            context,
            e,
            stackTrace: st,
            where: 'TransactionListPage.pullFromApi',
            actionLabel: 'Réessayer',
            onAction: () => _pullFromApiAndRefresh(),
          );
        }
      } finally {
        await _refreshLocal();
      }
    }

    Future<void> _acceptTxn(TransactionEntry e) async {
      String _normalizeType(String t) {
        final u = (t.isEmpty ? '' : t).toUpperCase();
        switch (u) {
          case 'IN':
            return 'CREDIT';
          case 'OUT':
            return 'DEBIT';
          default:
            return u;
        }
      }

      try {
        if ((e.status ?? '').toUpperCase() == 'COMPLETED') {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Déjà accepté')));
          }
          return;
        }
        final selectedId = ref.read(selectedAccountIdProvider);
        if ((selectedId ?? '').isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Aucun compte sélectionné')),
            );
          }
          return;
        }
        final repo = ref.read(transactionRepoProvider);
        final next = e.copyWith(
          status: 'COMPLETED',
          typeEntry: _normalizeType(e.typeEntry),
          accountId: selectedId,
          updatedAt: DateTime.now().toUtc(),
        );
        await repo.update(next);
        await _refreshLocal();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction acceptée. Solde mis à jour.'),
            ),
          );
        }
      } catch (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur : $err')));
        }
      }
    }

    Future<void> _rejectTxn(TransactionEntry e) async {
      final repo = ref.read(transactionRepoProvider);
      await repo.update(e.copyWith(status: 'REJECTED'));
      await _refreshLocal();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction rejetée')));
      }
    }

    final scaffold = Scaffold(
      body: RefreshIndicator(
        onRefresh: _pullFromApiAndRefresh,
        child: itemsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: const [
              Center(child: Text('Erreur de chargement')),
              SizedBox(height: 12),
              Center(
                child: Text(
                  'Tirez pour réessayer (pull-to-refresh).',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          data: (items) {
            final txns = items.cast<TransactionEntry>();
            final groups = groupByDay(txns);

            final exp = txns
                .where((e) => e.typeEntry.toUpperCase() == 'DEBIT')
                .fold<int>(0, (p, e) => p + e.amount);
            final inc = txns
                .where((e) => e.typeEntry.toUpperCase() == 'CREDIT')
                .fold<int>(0, (p, e) => p + e.amount);
            final net = inc - exp;

            final children = <Widget>[
              TransactionSummaryCard(
                periodLabel: state.label,
                onPrev: () =>
                    ref.read(transactionListStateProvider.notifier).prev(),
                onNext: () =>
                    ref.read(transactionListStateProvider.notifier).next(),
                onTapPeriod: () => _openAnchorPicker(context, ref),
                expenseCents: exp,
                incomeCents: inc,
                netCents: net,
                onOpenReport: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ReportPage())),
                onOpenSettings: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
                onAddExpense: () => _onAdd(context, ref, 'DEBIT'),
                onAddIncome: () => _onAdd(context, ref, 'CREDIT'),
                onAddDebt: () => _onAdd(context, ref, 'DEBT'),
                onAddRepayment: () => _onAdd(context, ref, 'REMBOURSEMENT'),
                onAddLoan: () => _onAdd(context, ref, 'PRET'),
                onOpenSearch: () => _openTxnSearch(context, txns),
              ),
              const SizedBox(height: 12),

              // ⬇️ État vide
              if (txns.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Text('Aucune transaction pour cette période'),
                      const SizedBox(height: 12),
                      // ⬇️ NEW: bouton "Demander un accès" si pas connecté
                      if (ref.read(accessSessionProvider) == null)
                        FilledButton.icon(
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Demander un accès'),
                          onPressed: () async {
                            final ok = await requireAccess(context, ref);
                            if (!context.mounted) return;
                            if (ok && ref.read(accessSessionProvider) != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Accès accordé.')),
                              );
                              // Optionnel : pull immédiat pour remplir
                              RestartApp.restart(context);
                            } else {
                              RestartApp.restart(context);
                            }
                          },
                        ),
                    ],
                  ),
                )
              else ...[
                for (final g in groups) ...[
                  DayHeader(group: g),
                  const SizedBox(height: 4),
                  ...g.items.map(
                    (e) => TransactionTile(
                      entry: e,
                      onDeleted: () async {
                        await ref
                            .read(transactionRepoProvider)
                            .softDelete(e.id);
                        await _refreshLocal();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Transaction supprimée'),
                            ),
                          );
                        }
                      },
                      onUpdated: _refreshLocal,
                      onSync: (_) async => _pullFromApiAndRefresh(),
                      onAccept: (entry) => _acceptTxn(entry),
                      onReject: (entry) => _rejectTxn(entry),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              TxnSearchCta(onTap: () => _openTxnSearch(context, txns)),
            ];

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: children,
            );
          },
        ),
      ),
    );

    final autoRefreshEnabled = ref.watch(autoRefreshOnFocusEnabledProvider);
    if (!autoRefreshEnabled) return scaffold;

    return AutoRefreshOnFocus(
      onRefocus: _pullFromApiAndRefresh,
      onlyWhenTag: 'chatbot',
      child: scaffold,
    );
  }

  Future<void> _openTxnSearch(
    BuildContext context,
    List<TransactionEntry> items,
  ) async {
    final result = await showSearch<TransactionEntry?>(
      context: context,
      delegate: TxnSearchDelegate(items),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sélectionné : ${result.description ?? result.code ?? result.id}',
          ),
        ),
      );
    }
  }

  Future<void> _openAnchorPicker(BuildContext context, WidgetRef ref) async {
    final state = ref.read(transactionListStateProvider);
    await showRightDrawer<void>(
      context,
      child: _PeriodDrawer(
        initialDate: state.anchor,
        onApply: (d) =>
            ref.read(transactionListStateProvider.notifier).setAnchor(d),
        onThisPeriod: () =>
            ref.read(transactionListStateProvider.notifier).resetToThisPeriod(),
      ),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
  }

  Future<void> _onAdd(BuildContext context, WidgetRef ref, String type) async {
    final ok = await showRightDrawer<bool>(
      context,
      child: TransactionQuickAddSheet(initialTypeEntry: type),
      widthFraction: 0.86,
      heightFraction: 0.96,
    );
    if (ok == true) {
      await ref.read(transactionsProvider.notifier).load();
      await ref.read(balanceProvider.notifier).load();
      ref.invalidate(transactionListItemsProvider);
    }
  }
}

class _PeriodDrawer extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onApply;
  final VoidCallback onThisPeriod;
  const _PeriodDrawer({
    required this.initialDate,
    required this.onApply,
    required this.onThisPeriod,
  });

  @override
  State<_PeriodDrawer> createState() => _PeriodDrawerState();
}

class _PeriodDrawerState extends State<_PeriodDrawer> {
  late DateTime _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Période'),
        actions: [
          TextButton(
            onPressed: widget.onThisPeriod,
            child: const Text('Ce mois'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          CalendarDatePicker(
            initialDate: _picked,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            onDateChanged: (d) => setState(() => _picked = d),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: FilledButton(
              onPressed: () {
                widget.onApply(_picked);
                Navigator.of(context).maybePop();
              },
              child: const Text('Appliquer'),
            ),
          ),
        ],
      ),
    );
  }
}
