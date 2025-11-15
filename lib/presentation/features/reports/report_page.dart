import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/account_selection.dart';
import 'report_range.dart';
import 'report_account_header.dart';
import 'report_period_selector.dart';
import 'report_totals_card.dart';
import 'report_pie_card.dart';
import 'report_dual_line_card.dart';
import 'report_breakdown_list.dart';

import 'package:jaayko/presentation/shared/formatters.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  /// true = Dépenses (DEBIT), false = Revenus (CREDIT) — utilisé pour camembert & breakdown
  bool isDebit = true;
  ReportRange range = ReportRange.thisMonth();

  @override
  Widget build(BuildContext context) {
    final accAsync = ref.watch(selectedAccountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport')),
      body: accAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (acc) {
          if (acc == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucun compte sélectionné.'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // En-tête compte courant
                ReportAccountHeader(account: acc),

                // Totaux : Dépenses, Revenus, Net
                ReportTotalsCard(
                  account: acc,
                  range: range,
                  activeIsDebit: isDebit, // ton bool existant
                  onToggleDebitCredit: (v) => setState(() {
                    // met à jour l’état parent
                    isDebit = v;
                  }),
                ),

                const SizedBox(height: 12),

                // Sélecteurs période + type (pour camembert/breakdown)
                ReportPeriodSelector(
                  range: range,
                  isDebit: isDebit,
                  onChangeRange: (r) => setState(() => range = r),
                  onToggleDebitCredit: (v) => setState(() => isDebit = v),
                ),

                const SizedBox(height: 12),

                const SizedBox(height: 12),

                // Camembert (selon isDebit)
                ReportPieCard(account: acc, range: range, isDebit: isDebit),

                const SizedBox(height: 16),

                // Courbe (debit + credit)
                ReportDualLineCard(account: acc, range: range),

                const SizedBox(height: 16),

                // Breakdown (liste des catégories) selon isDebit
                ReportBreakdownList(
                  account: acc,
                  range: range,
                  isDebit: isDebit,
                ),

                const SizedBox(height: 8),
                Text(
                  'Mis à jour ${Formatters.dateFull(DateTime.now())}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
