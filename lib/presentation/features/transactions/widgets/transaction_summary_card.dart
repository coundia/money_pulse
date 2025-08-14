// Orchestrates period header, summary metrics, and quick actions for transactions.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import 'summary_period_header.dart';
import 'summary_metric_chip.dart';
import 'summary_quick_actions.dart';

class TransactionSummaryCard extends StatelessWidget {
  final String periodLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapPeriod;
  final int expenseCents;
  final int incomeCents;
  final int netCents;
  final VoidCallback onOpenReport;
  final VoidCallback onOpenSettings;
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddIncome;

  const TransactionSummaryCard({
    super.key,
    required this.periodLabel,
    required this.onPrev,
    required this.onNext,
    required this.onTapPeriod,
    required this.expenseCents,
    required this.incomeCents,
    required this.netCents,
    required this.onOpenReport,
    required this.onOpenSettings,
    this.onAddExpense,
    this.onAddIncome,
  });

  @override
  Widget build(BuildContext context) {
    final netIsPositive = netCents >= 0;
    final netPrefix = netIsPositive ? '+' : '−';
    final netAbs = netCents.abs();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            SummaryPeriodHeader(
              label: periodLabel,
              onPrev: () {
                HapticFeedback.selectionClick();
                onPrev();
              },
              onNext: () {
                HapticFeedback.selectionClick();
                onNext();
              },
              onTapLabel: () {
                HapticFeedback.selectionClick();
                onTapPeriod();
              },
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (ctx, c) {
                final isTight = c.maxWidth < 420;
                return Wrap(
                  alignment: isTight
                      ? WrapAlignment.center
                      : WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    IconButton(
                      tooltip: 'Paramètres',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: onOpenSettings,
                    ),
                    SummaryMetricChip(
                      label: 'Dépenses',
                      valueText: '−${Formatters.amountFromCents(expenseCents)}',
                      tone: Theme.of(context).colorScheme.error,
                      semanticsValue:
                          '${Formatters.amountFromCents(expenseCents)} négatif',
                    ),
                    SummaryMetricChip(
                      label: 'Revenus',
                      valueText: '+${Formatters.amountFromCents(incomeCents)}',
                      tone: Theme.of(context).colorScheme.tertiary,
                      semanticsValue:
                          '${Formatters.amountFromCents(incomeCents)} positif',
                    ),
                    SummaryMetricChip(
                      label: 'Net',
                      valueText:
                          '$netPrefix${Formatters.amountFromCents(netAbs)}',
                      tone: netIsPositive
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.error,
                      semanticsValue:
                          '${Formatters.amountFromCents(netAbs)} ${netIsPositive ? 'positif' : 'négatif'}',
                    ),
                    IconButton(
                      tooltip: 'Rapport',
                      icon: const Icon(Icons.pie_chart),
                      onPressed: onOpenReport,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            SummaryQuickActions(
              onAddExpense: onAddExpense,
              onAddIncome: onAddIncome,
            ),
          ],
        ),
      ),
    );
  }
}
