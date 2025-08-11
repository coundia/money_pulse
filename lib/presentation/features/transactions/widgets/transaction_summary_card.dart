import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TransactionSummaryCard extends StatelessWidget {
  final String periodLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapPeriod;
  final String expenseText;
  final String incomeText;
  final String netText;
  final bool netPositive;
  final VoidCallback onOpenReport;
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddIncome;

  const TransactionSummaryCard({
    super.key,
    required this.periodLabel,
    required this.onPrev,
    required this.onNext,
    required this.onTapPeriod,
    required this.expenseText,
    required this.incomeText,
    required this.netText,
    required this.netPositive,
    required this.onOpenReport,
    this.onAddExpense,
    this.onAddIncome,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPrev,
                ),
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (c, a) =>
                          FadeTransition(opacity: a, child: c),
                      child: InkWell(
                        key: ValueKey(periodLabel),
                        onTap: onTapPeriod,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                periodLabel,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNext,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _summaryText(context, 'Expense', expenseText, Colors.red),
                _summaryText(context, 'Income', incomeText, Colors.green),
                _summaryText(
                  context,
                  'Net',
                  netText,
                  netPositive ? Colors.green : Colors.red,
                ),
                IconButton(
                  tooltip: 'Report',
                  icon: const Icon(Icons.pie_chart),
                  onPressed: onOpenReport,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ActionButtonsRow(
              onAddExpense: onAddExpense,
              onAddIncome: onAddIncome,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryText(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Responsive & polished buttons with better feedback, contrast and spacing.
class _ActionButtonsRow extends StatelessWidget {
  final VoidCallback? onAddExpense;
  final VoidCallback? onAddIncome;

  const _ActionButtonsRow({
    required this.onAddExpense,
    required this.onAddIncome,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final isNarrow = c.maxWidth < 360;
        final children = <Widget>[
          _ActionButton(
            label: 'Add expense',
            icon: Icons.remove_circle_outline,
            tone: Colors.red,
            onPressed: onAddExpense,
          ),
          SizedBox(width: isNarrow ? 0 : 12, height: isNarrow ? 12 : 0),
          _ActionButton(
            label: 'Add income',
            icon: Icons.add_circle_outline,
            tone: Colors.green,
            onPressed: onAddIncome,
          ),
        ];
        return isNarrow ? Column(children: children) : Row(children: children);
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final MaterialColor tone; // Use MaterialColor to access shades
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? tone.shade200 : tone.shade100).withOpacity(0.22);
    final fg = isDark ? tone.shade200 : tone.shade700;

    return Expanded(
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 400),
        child: FilledButton.icon(
          onPressed: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!.call();
                },
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          style:
              FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: bg,
                foregroundColor: fg,
                disabledForegroundColor: fg.withOpacity(0.38),
                disabledBackgroundColor: bg.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ).merge(
                ButtonStyle(
                  overlayColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.pressed)) {
                      return fg.withOpacity(0.08);
                    }
                    if (states.contains(MaterialState.hovered) ||
                        states.contains(MaterialState.focused)) {
                      return fg.withOpacity(0.06);
                    }
                    return null;
                  }),
                  elevation: MaterialStateProperty.resolveWith(
                    (states) => states.contains(MaterialState.pressed) ? 1 : 0,
                  ),
                  animationDuration: const Duration(milliseconds: 120),
                ),
              ),
        ),
      ),
    );
  }
}
