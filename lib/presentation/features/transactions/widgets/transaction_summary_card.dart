// UI card for period navigation, animated metrics, quick actions, and keyboard shortcuts; metrics open the report when tapped.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_pulse/presentation/shared/formatters.dart';

import 'summary_period_header.dart';
import 'summary_metric_chip.dart';
import 'summary_quick_actions.dart';

class PrevPeriodIntent extends Intent {
  const PrevPeriodIntent();
}

class NextPeriodIntent extends Intent {
  const NextPeriodIntent();
}

class OpenPeriodIntent extends Intent {
  const OpenPeriodIntent();
}

class OpenReportIntent extends Intent {
  const OpenReportIntent();
}

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class AddExpenseIntent extends Intent {
  const AddExpenseIntent();
}

class AddIncomeIntent extends Intent {
  const AddIncomeIntent();
}

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

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const PrevPeriodIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const NextPeriodIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyP): const OpenPeriodIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyR): const OpenReportIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyS): const OpenSettingsIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyE): const AddExpenseIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyI): const AddIncomeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          PrevPeriodIntent: CallbackAction<PrevPeriodIntent>(
            onInvoke: (_) {
              HapticFeedback.selectionClick();
              onPrev();
              return null;
            },
          ),
          NextPeriodIntent: CallbackAction<NextPeriodIntent>(
            onInvoke: (_) {
              HapticFeedback.selectionClick();
              onNext();
              return null;
            },
          ),
          OpenPeriodIntent: CallbackAction<OpenPeriodIntent>(
            onInvoke: (_) {
              HapticFeedback.selectionClick();
              onTapPeriod();
              return null;
            },
          ),
          OpenReportIntent: CallbackAction<OpenReportIntent>(
            onInvoke: (_) {
              HapticFeedback.selectionClick();
              onOpenReport();
              return null;
            },
          ),
          OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
            onInvoke: (_) {
              HapticFeedback.selectionClick();
              onOpenSettings();
              return null;
            },
          ),
          AddExpenseIntent: CallbackAction<AddExpenseIntent>(
            onInvoke: (_) {
              if (onAddExpense != null) {
                HapticFeedback.selectionClick();
                onAddExpense!.call();
              }
              return null;
            },
          ),
          AddIncomeIntent: CallbackAction<AddIncomeIntent>(
            onInvoke: (_) {
              if (onAddIncome != null) {
                HapticFeedback.selectionClick();
                onAddIncome!.call();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: false,
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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
                      final isTight = c.maxWidth < 520;
                      final wrapAlign = isTight
                          ? WrapAlignment.center
                          : WrapAlignment.spaceBetween;
                      return Wrap(
                        alignment: wrapAlign,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: _TappableMetric(
                              key: ValueKey('expense-$expenseCents'),
                              label: 'Dépenses',
                              valueText:
                                  '−${Formatters.amountFromCents(expenseCents)}',
                              tone: Theme.of(context).colorScheme.error,
                              semanticsValue:
                                  '${Formatters.amountFromCents(expenseCents)} négatif',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onOpenReport();
                              },
                              tooltip: 'Voir le rapport des dépenses',
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: _TappableMetric(
                              key: ValueKey('income-$incomeCents'),
                              label: 'Revenus',
                              valueText:
                                  '+${Formatters.amountFromCents(incomeCents)}',
                              tone: Theme.of(context).colorScheme.tertiary,
                              semanticsValue:
                                  '${Formatters.amountFromCents(incomeCents)} positif',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onOpenReport();
                              },
                              tooltip: 'Voir le rapport des revenus',
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: _TappableMetric(
                              key: ValueKey('net-$netCents'),
                              label: 'Net',
                              valueText:
                                  '${netPrefix}${Formatters.amountFromCents(netAbs)}',
                              tone: netIsPositive
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.error,
                              semanticsValue:
                                  '${Formatters.amountFromCents(netAbs)} ${netIsPositive ? 'positif' : 'négatif'}',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onOpenReport();
                              },
                              tooltip: 'Voir le rapport global',
                            ),
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
          ),
        ),
      ),
    );
  }
}

class _TappableMetric extends StatelessWidget {
  final String label;
  final String valueText;
  final Color tone;
  final String? semanticsValue;
  final VoidCallback onTap;
  final String tooltip;

  const _TappableMetric({
    super.key,
    required this.label,
    required this.valueText,
    required this.tone,
    required this.onTap,
    required this.tooltip,
    this.semanticsValue,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Semantics(
            button: true,
            onTapHint: 'Ouvrir le rapport',
            child: SummaryMetricChip(
              label: label,
              valueText: valueText,
              tone: tone,
              semanticsValue: semanticsValue,
            ),
          ),
        ),
      ),
    );
  }
}
