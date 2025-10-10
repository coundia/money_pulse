// File: lib/presentation/features/transactions/pages/transaction_list_page.dart
// Screen that lists transactions, groups by day, shows summary and wires tile actions including Accepter/Rejeter when status=INIT.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_pulse/domain/transactions/entities/transaction_entry.dart';
import 'package:money_pulse/presentation/app/providers.dart';
import 'package:money_pulse/presentation/widgets/right_drawer.dart';
import 'package:money_pulse/presentation/features/transactions/transaction_quick_add_sheet.dart';
import 'package:money_pulse/presentation/features/transactions/providers/transaction_list_providers.dart';
import 'package:money_pulse/presentation/features/transactions/utils/transaction_grouping.dart';
import 'package:money_pulse/presentation/features/transactions/widgets/day_header.dart';
import 'package:money_pulse/presentation/features/transactions/widgets/transaction_tile.dart';
import 'package:money_pulse/presentation/features/transactions/widgets/transaction_summary_card.dart';
import 'package:money_pulse/presentation/features/transactions/search/txn_search_delegate.dart';
import 'package:money_pulse/presentation/features/transactions/search/widgets/txn_search_cta.dart';
import 'package:money_pulse/presentation/features/settings/settings_page.dart';
import 'package:money_pulse/presentation/features/reports/report_page.dart';

import '../../../app/account_selection.dart';
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

    Future<void> _refreshAll() async {
      await ref.read(transactionsProvider.notifier).load();
      await ref.read(balanceProvider.notifier).load();
      ref.invalidate(transactionListItemsProvider);
    }

    Future<void> _acceptTxn(TransactionEntry e) async {
      // Normalise "IN"/"OUT" en "CREDIT"/"DEBIT" si nécessaire
      String _normalizeType(String t) {
        final u = (t.isEmpty ? '' : t).toUpperCase();
        switch (u) {
          case 'IN':
            return 'CREDIT';
          case 'OUT':
            return 'DEBIT';
          default:
            return u; // DEBIT, CREDIT, DEBT, REMBOURSEMENT, PRET...
        }
      }

      try {
        // Déjà accepté ? Ne rien refaire
        if ((e.status ?? '').toUpperCase() == 'COMPLETED') {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Déjà accepté')));
          }
          return;
        }

        // Récupère le compte sélectionné (obligatoire pour ajuster le solde)
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

        // Construit la version acceptée :
        // - status -> COMPLETED
        // - typeEntry normalisé (si IN/OUT)
        // - accountId -> compte sélectionné (déclenchera l’ajustement du solde)
        final next = e.copyWith(
          status: 'COMPLETED',
          typeEntry: _normalizeType(e.typeEntry),
          accountId: selectedId,
          updatedAt: DateTime.now().toUtc(),
        );

        // IMPORTANT : le repo s’occupe d’annuler l’ancien effet et d’appliquer le nouveau
        // (si l’ancienne transaction n’avait pas de compte, pas d’annulation ; on applique juste le delta)
        await repo.update(next);

        // Rafraîchit la liste et les soldes
        await ref.read(balanceProvider.notifier).load();
        await ref.read(transactionsProvider.notifier).load();
        ref.invalidate(transactionListItemsProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction acceptée. Solde mis à jour.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
        }
      }
    }

    Future<void> _rejectTxn(TransactionEntry e) async {
      final repo = ref.read(transactionRepoProvider);
      await repo.update(e.copyWith(status: 'REJECTED'));
      await _refreshAll();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction rejetée')));
      }
    }

    return Scaffold(
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
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
              onOpenReport: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ReportPage()));
              },
              onOpenSettings: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
              onAddExpense: () => _onAdd(context, ref, 'DEBIT'),
              onAddIncome: () => _onAdd(context, ref, 'CREDIT'),
              onAddDebt: () => _onAdd(context, ref, 'DEBT'),
              onAddRepayment: () => _onAdd(context, ref, 'REMBOURSEMENT'),
              onAddLoan: () => _onAdd(context, ref, 'PRET'),
              onOpenSearch: () => _openTxnSearch(context, txns),
            ),
            const SizedBox(height: 12),
            if (txns.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text('Aucune transaction pour cette période'),
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
                      await ref.read(transactionRepoProvider).softDelete(e.id);
                      await _refreshAll();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Transaction supprimée'),
                          ),
                        );
                      }
                    },
                    onUpdated: _refreshAll,
                    onSync: (entry) async {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Synchronisation lancée'),
                          ),
                        );
                      }
                    },
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
            padding: const EdgeInsets.all(12),
            children: children,
          );
        },
      ),
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
