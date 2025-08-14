// UI card for period navigation, animated metrics, quick actions, and keyboard shortcuts.
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

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):
            const ActivateIntent(), // précédent
        LogicalKeySet(LogicalKeyboardKey.arrowRight):
            const NextFocusIntent(), // suivant
        // période
        // rapport
        LogicalKeySet(LogicalKeyboardKey.keyS): const DirectionalFocusIntent(
          TraversalDirection.down,
        ), // paramètres
        LogicalKeySet(LogicalKeyboardKey.keyE):
            const DoNothingIntent(), // dépense
        LogicalKeySet(LogicalKeyboardKey.keyI):
            const DoNothingIntent(), // revenu
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              HapticFeedback.selectionClick();
              onPrev();
              return null;
            },
          ),
          NextFocusIntent: CallbackAction<NextFocusIntent>(
            onInvoke: (_) {
              HapticFeedback.selectionClick();
              onNext();
              return null;
            },
          ),
          RequestFocusIntent: CallbackAction<RequestFocusIntent>(
            onInvoke: (_) {
              HapticFeedback.selectionClick();
              onTapPeriod();
              return null;
            },
          ),
          SelectIntent: CallbackAction<SelectIntent>(
            onInvoke: (_) {
              HapticFeedback.selectionClick();
              onOpenReport();
              return null;
            },
          ),
          DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
            onInvoke: (_) {
              HapticFeedback.selectionClick();
              onOpenSettings();
              return null;
            },
          ),
          DoNothingIntent: CallbackAction<DoNothingIntent>(
            onInvoke: (i) {
              final lastKey =
                  HardwareKeyboard.instance.logicalKeysPressed.lastOrNull;
              if (lastKey == LogicalKeyboardKey.keyE && onAddExpense != null) {
                HapticFeedback.selectionClick();
                onAddExpense!.call();
              } else if (lastKey == LogicalKeyboardKey.keyI &&
                  onAddIncome != null) {
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
                      final isTight = c.maxWidth < 420;
                      final wrapAlign = isTight
                          ? WrapAlignment.center
                          : WrapAlignment.spaceBetween;
                      return Wrap(
                        alignment: wrapAlign,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _IconFilledTonal(
                            tooltip: 'Paramètres',
                            icon: Icons.settings_outlined,
                            onPressed: onOpenSettings,
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: SummaryMetricChip(
                              key: ValueKey('expense-$expenseCents'),
                              label: 'Dépenses',
                              valueText:
                                  '−${Formatters.amountFromCents(expenseCents)}',
                              tone: Theme.of(context).colorScheme.error,
                              semanticsValue:
                                  '${Formatters.amountFromCents(expenseCents)} négatif',
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: SummaryMetricChip(
                              key: ValueKey('income-$incomeCents'),
                              label: 'Revenus',
                              valueText:
                                  '+${Formatters.amountFromCents(incomeCents)}',
                              tone: Theme.of(context).colorScheme.tertiary,
                              semanticsValue:
                                  '${Formatters.amountFromCents(incomeCents)} positif',
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: SummaryMetricChip(
                              key: ValueKey('net-$netCents'),
                              label: 'Net',
                              valueText:
                                  '$netPrefix${Formatters.amountFromCents(netAbs)}',
                              tone: netIsPositive
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.error,
                              semanticsValue:
                                  '${Formatters.amountFromCents(netAbs)} ${netIsPositive ? 'positif' : 'négatif'}',
                            ),
                          ),
                          _IconFilledTonal(
                            tooltip: 'Rapport',
                            icon: Icons.pie_chart,
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
          ),
        ),
      ),
    );
  }
}

class _IconFilledTonal extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _IconFilledTonal({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.54);
    final fg = Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        icon: Icon(icon),
        label: Text(tooltip),
      ),
    );
  }
}
